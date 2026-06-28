import AppKit
import WSCore

/// The editing canvas: a custom layer-backed NSView that owns every keystroke,
/// renders an 80-column character grid letter-boxed into the window, and repaints
/// only the cells that actually changed. This is the latency-critical surface.
final class EditorView: NSView, NSWindowDelegate, NSMenuItemValidation {

    // MARK: Configuration
    private let theme = Theme.amber
    private let textColumns = 80
    private let statusRow = 0

    // MARK: Fonts (regular + style variants for inline formatting)
    private let font: NSFont
    private let boldFont: NSFont
    private let italicFont: NSFont
    private let boldItalicFont: NSFont
    private let cellW: CGFloat
    private let cellH: CGFloat

    // MARK: State
    private let grid: CellGrid
    private var doc = Document(wrapWidth: 65)
    private var scrollTop = 0
    private var fileName = "UNTITLED.WS"
    private var helpLevel = 3      // 0 = no menu … 3 = full WordStar main menu

    // MARK: File
    private var filePath: URL?
    private var savedRevision = 0
    private var isDirty: Bool { doc.revision != savedRevision }

    // MARK: CRT effects (toggleable; no screen curvature, kept subtle)
    private var scanlinesOn = true
    private var glowOn = true

    // MARK: Command FSM / prompt
    private enum InputState { case normal, awaitBlock, awaitQuick, awaitPrint }
    private enum Prompt { case find, replaceSearch, replaceWith(String) }
    private var inputState: InputState = .normal
    private var prompt: Prompt?
    private var promptBuffer = ""
    private var message: String?
    private var promptCaretCol = 0

    // MARK: Geometry
    private var originX: CGFloat = 0
    private var originY: CGFloat = 0

    // MARK: Cursor
    private var gridCursorRow = 0
    private var gridCursorCol = 0
    private var cursorOn = true
    private var blinkTimer: Timer?

    // MARK: - Layout of header rows (driven by help level)

    private var menuRowCount: Int {
        switch helpLevel { case 0: return 0; case 1: return 1; case 2: return 3; default: return 4 }
    }
    private var infoRowIndex: Int { 1 + menuRowCount }   // ruler / prompt / message
    private var firstTextRow: Int { infoRowIndex + 1 }
    private var textRows: Int { max(0, grid.rows - firstTextRow) }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        let base = NSFont(name: "Menlo", size: 14)
            ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let fm = NSFontManager.shared
        self.font = base
        self.boldFont = fm.convert(base, toHaveTrait: .boldFontMask)
        self.italicFont = fm.convert(base, toHaveTrait: .italicFontMask)
        self.boldItalicFont = fm.convert(fm.convert(base, toHaveTrait: .boldFontMask),
                                         toHaveTrait: .italicFontMask)
        let probe = ("M" as NSString).size(withAttributes: [.font: base])
        self.cellW = ceil(probe.width)
        self.cellH = ceil(base.ascender - base.descender + base.leading)
        self.grid = CellGrid(cols: 80, rows: 25)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = theme.border.cgColor
        computeGeometry()
        renderGrid()
        updateCursorPosition(invalidateOld: false)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    var preferredContentWidth: CGFloat { cellW * CGFloat(textColumns) + 24 }

    // MARK: - Responder / focus

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func becomeFirstResponder() -> Bool { startBlink(); return true }
    override func resignFirstResponder() -> Bool {
        blinkTimer?.invalidate(); cursorOn = true; return true
    }

    // MARK: - Geometry

    private func computeGeometry() {
        let availW = bounds.width
        let availH = bounds.height
        let rows = max(firstTextRow + 1, Int(floor(availH / cellH)))
        if rows != grid.rows { grid.resize(cols: textColumns, rows: rows) }
        let gridW = cellW * CGFloat(textColumns)
        let gridH = CGFloat(rows) * cellH
        originX = floor((availW - gridW) / 2)
        originY = floor((availH - gridH) / 2)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        computeGeometry()
        clampScroll()
        renderGrid()
        updateCursorPosition(invalidateOld: false)
        needsDisplay = true
    }

    private func clampScroll() {
        let line = doc.cursorLine
        if line < scrollTop { scrollTop = line }
        if line >= scrollTop + textRows { scrollTop = line - textRows + 1 }
        if scrollTop < 0 { scrollTop = 0 }
    }

    @inline(__always)
    private func cellRect(_ r: Int, _ c: Int) -> NSRect {
        NSRect(x: originX + CGFloat(c) * cellW,
               y: originY + CGFloat(r) * cellH,
               width: cellW, height: cellH)
    }

    // MARK: - Rendering (model -> grid, diffed)

    private func setCell(_ r: Int, _ c: Int, _ cell: Cell) {
        guard r >= 0, c >= 0, r < grid.rows, c < grid.cols else { return }
        if grid.set(r, c, cell) { setNeedsDisplay(cellRect(r, c)) }
    }

    private func renderGrid() {
        clampScroll()
        renderStatusLine()
        renderMenu()
        renderInfoRow()
        renderText()
    }

    private func writeRow(_ row: Int, _ text: String, role: CellRole) {
        let chars = Array(text)
        for c in 0..<grid.cols {
            let ch: Character = c < chars.count ? chars[c] : " "
            setCell(row, c, Cell(ch: ch, role: role))
        }
    }

    private func renderStatusLine() {
        let pos = "L\(doc.cursorLine + 1) C\(doc.cursorColumn + 1)"
        let mode = doc.insertMode ? "INSERT" : "OVERTYPE"
        let blk = doc.blockRange != nil ? "  BLOCK" : ""
        writeRow(statusRow, "  \(fileName)    \(pos)    \(mode)\(blk)    HELP \(helpLevel)",
                 role: .status)
    }

    private func renderMenu() {
        let lines = menuLines()
        for i in 0..<menuRowCount {
            writeRow(1 + i, i < lines.count ? lines[i] : "", role: .ruler)
        }
    }

    private func menuLines() -> [String] {
        switch helpLevel {
        case 1:
            return ["^Q Quick  ^K Block  ^P Print  ^B Reform  ^L Find-next  ^U Undo  ^J Help-"]
        case 2:
            return [
                "  <<<  M A I N   M E N U  >>>",
                "Cursor ^E/^X up/dn  ^S/^D l/r  ^A/^F word  ^R/^C page",
                "Block ^K   Quick ^Q   Print ^P   Reform ^B   Undo ^U   Help ^J",
            ]
        default:
            return [
                "  <<<  M A I N   M E N U  >>>          press ^J to change help level",
                "Cursor           Scroll       Delete          Misc          Menus",
                "^E up   ^X down   ^R pg-up     ^G char         ^V ins/over   ^K Block",
                "^S/^D ^A/^F word  ^C pg-down   ^T word ^Y line ^B reform     ^Q Quick ^P Print",
            ]
        }
    }

    private func renderInfoRow() {
        if let p = prompt {
            let label: String
            switch p {
            case .find:          label = "Find: "
            case .replaceSearch: label = "Replace — find: "
            case .replaceWith:   label = "Replace with: "
            }
            let text = label + promptBuffer
            promptCaretCol = min(text.count, grid.cols - 1)
            writeRow(infoRowIndex, text, role: .status)
            return
        }
        if let m = message {
            writeRow(infoRowIndex, m, role: .status)
            return
        }
        renderRuler()
    }

    private func renderRuler() {
        for c in 0..<grid.cols {
            var ch: Character = "-"
            if c == 0 { ch = "L" }
            else if c == 64 { ch = "R" }
            else if c % 5 == 0 { ch = "!" }
            setCell(infoRowIndex, c, Cell(ch: ch, role: .ruler))
        }
    }

    private func renderText() {
        let block = doc.blockHidden ? nil : doc.blockRange
        for vl in 0..<textRows {
            let gridRow = firstTextRow + vl
            let lineIndex = scrollTop + vl

            guard lineIndex < doc.lineCount else {
                for c in 0..<grid.cols { setCell(gridRow, c, Cell(ch: " ", role: .text)) }
                continue
            }

            let chars = doc.lineText(lineIndex)
            let lineStart = doc.lineStartOffset(lineIndex)

            if doc.lineIsDot(lineIndex) {
                for c in 0..<grid.cols {
                    let ch: Character = c < chars.count ? chars[c] : " "
                    setCell(gridRow, c, Cell(ch: ch, role: .ruler))   // dot line: dimmed
                }
                continue
            }

            let indent = doc.lineLeftIndent(lineIndex)
            // A line that begins a new page carries a divider on every cell's top
            // edge (so the diff repaints/clears it when the break moves) plus a
            // right-aligned "Page N" label written into the grid.
            let isBreak = doc.pageBreakBeforeLine.contains(lineIndex)
            var attrs = doc.lineEntryAttrs(lineIndex)
            for c in 0..<grid.cols {
                let ci = c - indent   // index into the line's characters
                guard ci >= 0, ci < chars.count else {
                    setCell(gridRow, c, Cell(ch: " ", role: .text, pageBreakTop: isBreak)); continue
                }
                let ch = chars[ci]
                let off = lineStart + ci
                let inBlock = block.map { off >= $0.lowerBound && off < $0.upperBound } ?? false

                if let f = formatToggled(by: ch) {
                    // Show the control byte as a highlighted marker letter.
                    var cell = Cell(ch: formatMarkerLetter(ch) ?? "?", role: .text)
                    cell.inverse = true
                    cell.pageBreakTop = isBreak
                    setCell(gridRow, c, cell)
                    attrs.toggle(f)
                } else {
                    var cell = Cell(ch: ch, role: .text)
                    cell.bold = attrs.bold
                    cell.underline = attrs.underline
                    cell.italic = attrs.italic
                    cell.inverse = inBlock
                    cell.pageBreakTop = isBreak
                    setCell(gridRow, c, cell)
                }
            }

            if isBreak {
                let label = Array("Page \(pageNumber(forBreakLine: lineIndex))")
                let start = max(indent + chars.count + 1, grid.cols - label.count)
                for (i, ch) in label.enumerated() where start + i < grid.cols {
                    setCell(gridRow, start + i, Cell(ch: ch, role: .ruler, pageBreakTop: true))
                }
            }
        }
    }

    /// Page number that begins at a page-break line (page 1 is the first page).
    private func pageNumber(forBreakLine lineIndex: Int) -> Int {
        var n = 1
        for b in doc.pageBreakBeforeLine where b <= lineIndex { n += 1 }
        return n
    }

    // MARK: - Cursor

    private func updateCursorPosition(invalidateOld: Bool) {
        let oldR = gridCursorRow, oldC = gridCursorCol
        if prompt != nil {
            gridCursorRow = infoRowIndex
            gridCursorCol = promptCaretCol
        } else {
            gridCursorRow = firstTextRow + (doc.cursorLine - scrollTop)
            let indent = doc.lineLeftIndent(doc.cursorLine)
            gridCursorCol = min(indent + doc.cursorColumn, grid.cols - 1)
        }
        cursorOn = true
        restartBlink()
        if invalidateOld { setNeedsDisplay(cellRect(oldR, oldC)) }
        setNeedsDisplay(cellRect(gridCursorRow, gridCursorCol))
    }

    private func startBlink() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.cursorOn.toggle()
            self.setNeedsDisplay(self.cellRect(self.gridCursorRow, self.gridCursorCol))
        }
    }

    private func restartBlink() { if blinkTimer != nil { startBlink() } }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        theme.border.setFill()
        dirtyRect.fill()

        let cMin = max(0, Int(floor((dirtyRect.minX - originX) / cellW)))
        let cMax = min(grid.cols - 1, Int(floor((dirtyRect.maxX - originX) / cellW)))
        let rMin = max(0, Int(floor((dirtyRect.minY - originY) / cellH)))
        let rMax = min(grid.rows - 1, Int(floor((dirtyRect.maxY - originY) / cellH)))
        guard cMin <= cMax, rMin <= rMax else { return }

        for r in rMin...rMax {
            for c in cMin...cMax { drawCell(r, c) }
        }

        if scanlinesOn { drawScanlines(in: dirtyRect) }
    }

    /// Faint dark horizontal lines across the whole surface. Drawn in absolute
    /// coordinates so the phase stays consistent as only dirty cells repaint.
    private func drawScanlines(in dirtyRect: NSRect) {
        let step: CGFloat = 3
        NSColor(white: 0, alpha: 0.14).setFill()
        var y = (dirtyRect.minY / step).rounded(.down) * step
        while y < dirtyRect.maxY {
            NSRect(x: dirtyRect.minX, y: y, width: dirtyRect.width, height: 1).fill()
            y += step
        }
    }

    private func drawCell(_ r: Int, _ c: Int) {
        let cell = grid.cell(r, c)
        var (fg, bg) = colors(for: cell)

        let isCursor = cursorOn && r == gridCursorRow && c == gridCursorCol
        if isCursor { bg = theme.cursor; fg = theme.textBG }

        let rect = cellRect(r, c)
        bg.setFill()
        rect.fill()

        if cell.ch != " " {
            let glyphFont: NSFont
            switch (cell.bold, cell.italic) {
            case (true, true):   glyphFont = boldItalicFont
            case (true, false):  glyphFont = boldFont
            case (false, true):  glyphFont = italicFont
            case (false, false): glyphFont = font
            }
            var attrs: [NSAttributedString.Key: Any] = [.font: glyphFont, .foregroundColor: fg]
            if cell.underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }

            if glowOn {
                NSGraphicsContext.saveGraphicsState()
                let glow = NSShadow()
                glow.shadowColor = fg.withAlphaComponent(0.85)
                glow.shadowBlurRadius = 3
                glow.shadowOffset = .zero
                glow.set()
                (String(cell.ch) as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY),
                                                   withAttributes: attrs)
                NSGraphicsContext.restoreGraphicsState()
            } else {
                (String(cell.ch) as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY),
                                                   withAttributes: attrs)
            }
        }

        // Page-boundary rule: a thin line along the top edge of a new page's
        // first row. Driven by the cell's own `pageBreakTop` flag so it's part
        // of the diff — drawn inside this cell's rect (never clipped) and cleared
        // automatically when the break moves. Segments tile into a full rule.
        if cell.pageBreakTop {
            theme.rulerFG.withAlphaComponent(0.7).setFill()
            NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1).fill()
        }
    }

    private func colors(for cell: Cell) -> (NSColor, NSColor) {
        var fg: NSColor
        var bg: NSColor
        switch cell.role {
        case .status: fg = theme.statusFG; bg = theme.statusBG
        case .ruler:  fg = theme.rulerFG;  bg = theme.textBG
        case .text, .blank: fg = theme.textFG; bg = theme.textBG
        }
        if cell.inverse { swap(&fg, &bg) }
        return (fg, bg)
    }

    // MARK: - Input

    override func keyDown(with event: NSEvent) {
        if prompt != nil {
            if event.modifierFlags.contains(.command) { super.keyDown(with: event) }
            else { handlePrompt(event) }
            return
        }

        let flags = event.modifierFlags
        if flags.contains(.command) { super.keyDown(with: event); return }

        switch inputState {
        case .awaitBlock: completeBlockPrefix(event); return
        case .awaitQuick: completePrefix(event, resolveQuickCommand); return
        case .awaitPrint: completePrint(event); return
        case .normal: break
        }

        if message != nil { message = nil }
        if flags.contains(.control) { handleControl(event); return }

        switch event.keyCode {
        case 36, 76:  doc.insertNewline()
        case 51:      doc.backspace()
        case 117:     doc.deleteForward()
        case 123:     doc.moveLeft()
        case 124:     doc.moveRight()
        case 125:     doc.moveDown()
        case 126:     doc.moveUp()
        case 115:     doc.lineStart()
        case 119:     doc.lineEnd()
        case 116:     doc.pageUp(rows: textRows)
        case 121:     doc.pageDown(rows: textRows)
        default:      insertPrintable(event)
        }
        refresh()
    }

    private func handleControl(_ event: NSEvent) {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "k": inputState = .awaitBlock; message = "^K  B/K mark  C copy  V move  Y delete  H hide  |  S save  R read  D done"
        case "q": inputState = .awaitQuick; message = "^Q  S/D line  R/C doc  B/K block  F find  A replace  Y del-eol"
        case "p": inputState = .awaitPrint; message = "^P  B bold  S underline  Y italic"
        case "e": doc.moveUp()
        case "x": doc.moveDown()
        case "s": doc.moveLeft()
        case "d": doc.moveRight()
        case "a": doc.wordLeft()
        case "f": doc.wordRight()
        case "r": doc.pageUp(rows: textRows)
        case "c": doc.pageDown(rows: textRows)
        case "g": doc.deleteForward()
        case "h": doc.backspace()
        case "t": doc.deleteWordRight()
        case "y": doc.deleteLine()
        case "b": doc.reformParagraph()
        case "v": doc.toggleInsertMode()
        case "u": doc.undo()
        case "l": runFindNext()
        case "j": cycleHelpLevel()
        default: break
        }
        refresh()
    }

    private func cycleHelpLevel() {
        helpLevel = helpLevel == 0 ? 3 : helpLevel - 1
        computeGeometry()
        clampScroll()
        needsDisplay = true
    }

    private func completePrefix(_ event: NSEvent, _ resolver: (Character) -> EditorCommand?) {
        inputState = .normal
        message = nil
        if event.keyCode == 53 { refresh(); return }   // Esc cancels
        guard let ch = event.charactersIgnoringModifiers?.first,
              let cmd = resolver(ch) else { refresh(); return }
        execute(cmd)
        refresh()
    }

    /// The ^K menu mixes block commands and file commands (as in WordStar).
    private func completeBlockPrefix(_ event: NSEvent) {
        inputState = .normal
        message = nil
        if event.keyCode == 53 { refresh(); return }   // Esc
        guard let ch = event.charactersIgnoringModifiers?.first else { refresh(); return }
        switch Character(ch.lowercased()) {
        case "s", "d", "x": saveDocument()             // save (and "done"/"exit")
        case "r":           openDocument()             // read/open a file
        default:
            if let cmd = resolveBlockCommand(ch) { execute(cmd) }
        }
        refresh()
    }

    private func completePrint(_ event: NSEvent) {
        inputState = .normal
        message = nil
        if event.keyCode == 53 { refresh(); return }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "b": doc.insertFormat(.bold)
        case "s": doc.insertFormat(.underline)
        case "y": doc.insertFormat(.italic)
        default: break
        }
        refresh()
    }

    private func execute(_ cmd: EditorCommand) {
        switch cmd {
        case .markBlockBegin: doc.markBlockBegin()
        case .markBlockEnd:   doc.markBlockEnd()
        case .copyBlock:      doc.copyBlockAtCursor()
        case .moveBlock:      doc.moveBlock()
        case .deleteBlock:    doc.deleteBlock()
        case .hideBlock:      doc.toggleBlockHidden()
        case .toBlockBegin:   doc.toBlockBegin()
        case .toBlockEnd:     doc.toBlockEnd()
        case .lineStart:      doc.lineStart()
        case .lineEnd:        doc.lineEnd()
        case .docStart:       doc.documentStart()
        case .docEnd:         doc.documentEnd()
        case .deleteToLineEnd: doc.deleteToLineEnd()
        case .find:           startPrompt(.find)
        case .findReplace:    startPrompt(.replaceSearch)
        }
    }

    private func insertPrintable(_ event: NSEvent) {
        guard let chars = event.characters else { return }
        for ch in chars {
            guard let scalar = ch.unicodeScalars.first else { continue }
            if scalar.value >= 0x20 && scalar.value != 0x7f { doc.insertChar(ch) }
        }
    }

    // MARK: - Find / replace prompt

    private func startPrompt(_ kind: Prompt) {
        prompt = kind
        promptBuffer = ""
        message = nil
        refresh()
    }

    private func handlePrompt(_ event: NSEvent) {
        switch event.keyCode {
        case 53:        prompt = nil; message = nil
        case 36, 76:    confirmPrompt(); return
        case 51:        if !promptBuffer.isEmpty { promptBuffer.removeLast() }
        default:
            if let chars = event.characters {
                for ch in chars {
                    if let s = ch.unicodeScalars.first, s.value >= 0x20, s.value != 0x7f {
                        promptBuffer.append(ch)
                    }
                }
            }
        }
        refresh()
    }

    private func confirmPrompt() {
        guard let p = prompt else { return }
        let entry = promptBuffer
        switch p {
        case .find:
            prompt = nil
            message = doc.find(Array(entry)) ? nil : "Not found: \(entry)"
        case .replaceSearch:
            prompt = .replaceWith(entry)
            promptBuffer = ""
            refresh()
            return
        case .replaceWith(let needle):
            prompt = nil
            let n = doc.replaceAll(Array(needle), with: Array(entry))
            message = "\(n) replacement\(n == 1 ? "" : "s")"
        }
        refresh()
    }

    private func runFindNext() {
        if !doc.findNext() { message = "Not found" }
    }

    private func refresh() {
        renderGrid()
        updateCursorPosition(invalidateOld: true)
        updateTitle()
    }

    // MARK: - File I/O

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.delegate = self
        updateTitle()
    }

    private func updateTitle() {
        fileName = (filePath?.lastPathComponent ?? "UNTITLED.WS")
        window?.title = (isDirty ? "• " : "") + "WordStar — " + fileName
    }

    private func newDocument() {
        guard confirmDiscardIfNeeded() else { return }
        doc = Document(wrapWidth: 65)
        filePath = nil
        savedRevision = doc.revision
        scrollTop = 0
        refresh()
    }

    private func openDocument() {
        guard confirmDiscardIfNeeded() else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else { message = "Can't read \(url.lastPathComponent)"; refresh(); return }
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) ?? ""
        doc = Document(text: text, wrapWidth: 65)
        filePath = url
        savedRevision = doc.revision
        scrollTop = 0
        message = "Opened \(url.lastPathComponent)"
        refresh()
    }

    @discardableResult
    private func saveDocument() -> Bool {
        guard let url = filePath else { return saveDocumentAs() }
        return write(to: url)
    }

    @discardableResult
    private func saveDocumentAs() -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filePath?.lastPathComponent ?? "UNTITLED.WS"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        filePath = url
        return write(to: url)
    }

    private func write(to url: URL) -> Bool {
        let fm = FileManager.default
        // WordStar-style .BAK backup of the previous version.
        if fm.fileExists(atPath: url.path) {
            let bak = url.deletingPathExtension().appendingPathExtension("BAK")
            try? fm.removeItem(at: bak)
            try? fm.copyItem(at: url, to: bak)
        }
        do {
            try doc.text().write(to: url, atomically: true, encoding: .utf8)
            savedRevision = doc.revision
            message = "Saved \(url.lastPathComponent)"
            refresh()
            return true
        } catch {
            message = "Save failed: \(error.localizedDescription)"
            refresh()
            return false
        }
    }

    /// Returns true if it's safe to proceed (discard current changes).
    private func confirmDiscardIfNeeded() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(fileName)?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:  return saveDocument()
        case .alertSecondButtonReturn: return true
        default:                       return false
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmDiscardIfNeeded()
    }

    // MARK: - Menu actions (native keys mirroring WordStar commands)

    @objc func wsCopy(_ sender: Any?) {
        guard let text = doc.blockText() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        message = "Copied"
        refresh()
    }

    @objc func wsCut(_ sender: Any?) {
        guard let text = doc.blockText() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        doc.deleteBlock()
        refresh()
    }

    @objc func wsPaste(_ sender: Any?) {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return }
        // Normalise line endings to the document's '\n'.
        let text = raw.replacingOccurrences(of: "\r\n", with: "\n")
                      .replacingOccurrences(of: "\r", with: "\n")
        doc.insertText(text)
        refresh()
    }

    @objc func wsToggleScanlines(_ sender: Any?) { scanlinesOn.toggle(); needsDisplay = true }
    @objc func wsToggleGlow(_ sender: Any?)      { glowOn.toggle(); needsDisplay = true }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(wsToggleScanlines(_:)): menuItem.state = scanlinesOn ? .on : .off
        case #selector(wsToggleGlow(_:)):      menuItem.state = glowOn ? .on : .off
        case #selector(wsCopy(_:)), #selector(wsCut(_:)):
            return doc.blockRange != nil
        case #selector(wsPaste(_:)):
            return NSPasteboard.general.string(forType: .string) != nil
        default: break
        }
        return true
    }

    @objc func wsNew(_ sender: Any?)      { newDocument() }
    @objc func wsOpen(_ sender: Any?)     { openDocument() }
    @objc func wsSave(_ sender: Any?)     { saveDocument() }
    @objc func wsSaveAs(_ sender: Any?)   { saveDocumentAs() }
    @objc func wsUndo(_ sender: Any?)     { doc.undo(); refresh() }
    @objc func wsRedo(_ sender: Any?)     { doc.redo(); refresh() }
    @objc func wsFind(_ sender: Any?)     { startPrompt(.find) }
    @objc func wsFindNext(_ sender: Any?) { runFindNext(); refresh() }
    @objc func wsReplace(_ sender: Any?)  { startPrompt(.replaceSearch) }
}
