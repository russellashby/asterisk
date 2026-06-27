import AppKit

/// The editing canvas: a custom layer-backed NSView that owns every keystroke,
/// renders an 80-column character grid letter-boxed into the window, and repaints
/// only the cells that actually changed. This is the latency-critical surface.
final class EditorView: NSView {

    // MARK: Configuration
    private let theme = Theme.classic
    private let textColumns = 80
    private let statusRow = 0
    private let rulerRow  = 1
    private let firstTextRow = 2

    // MARK: Font metrics
    private let font: NSFont
    private let cellW: CGFloat
    private let cellH: CGFloat

    // MARK: State
    private let grid: CellGrid
    private let model = TextModel()
    private var scrollTop = 0
    private var fileName = "UNTITLED.WS"

    // MARK: Geometry (recomputed on resize)
    private var originX: CGFloat = 0
    private var originY: CGFloat = 0

    // MARK: Cursor
    private var gridCursorRow = 0
    private var gridCursorCol = 0
    private var cursorOn = true
    private var blinkTimer: Timer?

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        let f = NSFont(name: "Menlo", size: 14)
            ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        self.font = f
        let probe = ("M" as NSString).size(withAttributes: [.font: f])
        self.cellW = ceil(probe.width)
        self.cellH = ceil(f.ascender - f.descender + f.leading)
        self.grid = CellGrid(cols: 80, rows: 25)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = theme.border.cgColor
        computeGeometry()
        renderGrid()
        updateCursorPosition(invalidateOld: false)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Preferred window content width so 80 columns fit with a little margin.
    var preferredContentWidth: CGFloat { cellW * CGFloat(textColumns) + 24 }

    // MARK: - Responder / focus

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }   // row 0 at the top

    override func becomeFirstResponder() -> Bool {
        startBlink()
        return true
    }

    override func resignFirstResponder() -> Bool {
        blinkTimer?.invalidate()
        cursorOn = true
        return true
    }

    // MARK: - Geometry

    private func computeGeometry() {
        let availW = bounds.width
        let availH = bounds.height
        let rows = max(firstTextRow + 1, Int(floor(availH / cellH)))
        if rows != grid.rows {
            grid.resize(cols: textColumns, rows: rows)
        }
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

    private var textRows: Int { grid.rows - firstTextRow }

    private func clampScroll() {
        if model.cy < scrollTop { scrollTop = model.cy }
        if model.cy >= scrollTop + textRows { scrollTop = model.cy - textRows + 1 }
        if scrollTop < 0 { scrollTop = 0 }
    }

    @inline(__always)
    private func cellRect(_ r: Int, _ c: Int) -> NSRect {
        NSRect(x: originX + CGFloat(c) * cellW,
               y: originY + CGFloat(r) * cellH,
               width: cellW, height: cellH)
    }

    // MARK: - Rendering (model -> grid, diffed)

    /// Set a cell only if it changed, invalidating just that cell's rect.
    private func setCell(_ r: Int, _ c: Int, _ cell: Cell) {
        guard r >= 0, c >= 0, r < grid.rows, c < grid.cols else { return }
        if grid.set(r, c, cell) {
            setNeedsDisplay(cellRect(r, c))
        }
    }

    private func renderGrid() {
        clampScroll()
        renderStatusLine()
        renderRuler()
        renderText()
    }

    private func renderStatusLine() {
        let pos = "PAGE 1  LINE \(model.cy + 1)  COL \(model.cx + 1)"
        let text = "  \(fileName)    \(pos)    INSERT ON"
        let chars = Array(text)
        for c in 0..<grid.cols {
            let ch: Character = c < chars.count ? chars[c] : " "
            setCell(statusRow, c, Cell(ch: ch, role: .status))
        }
    }

    private func renderRuler() {
        for c in 0..<grid.cols {
            var ch: Character = "-"
            if c == 0 { ch = "L" }
            else if c == 64 { ch = "R" }
            else if c % 5 == 0 { ch = "!" }
            setCell(rulerRow, c, Cell(ch: ch, role: .ruler))
        }
    }

    private func renderText() {
        for vl in 0..<textRows {
            let gridRow = firstTextRow + vl
            let lineIndex = scrollTop + vl
            let line: [Character] = (lineIndex < model.lines.count) ? model.lines[lineIndex] : []
            for c in 0..<grid.cols {
                let ch: Character = c < line.count ? line[c] : " "
                setCell(gridRow, c, Cell(ch: ch, role: .text))
            }
        }
    }

    // MARK: - Cursor

    private func updateCursorPosition(invalidateOld: Bool) {
        let oldR = gridCursorRow, oldC = gridCursorCol
        gridCursorRow = firstTextRow + (model.cy - scrollTop)
        gridCursorCol = min(model.cx, grid.cols - 1)
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

    private func restartBlink() {
        // Keep the cursor solid right after activity, then resume blinking.
        if blinkTimer != nil { startBlink() }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Letter-box surround.
        theme.border.setFill()
        dirtyRect.fill()

        // Only iterate cells that intersect the dirty rect.
        let cMin = max(0, Int(floor((dirtyRect.minX - originX) / cellW)))
        let cMax = min(grid.cols - 1, Int(floor((dirtyRect.maxX - originX) / cellW)))
        let rMin = max(0, Int(floor((dirtyRect.minY - originY) / cellH)))
        let rMax = min(grid.rows - 1, Int(floor((dirtyRect.maxY - originY) / cellH)))
        guard cMin <= cMax, rMin <= rMax else { return }

        for r in rMin...rMax {
            for c in cMin...cMax {
                drawCell(r, c)
            }
        }
    }

    private func drawCell(_ r: Int, _ c: Int) {
        let cell = grid.cell(r, c)
        var (fg, bg) = colors(for: cell)

        let isCursor = cursorOn && r == gridCursorRow && c == gridCursorCol
        if isCursor {
            bg = theme.cursor
            fg = theme.textBG
        }

        let rect = cellRect(r, c)
        bg.setFill()
        rect.fill()

        if cell.ch != " " {
            var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
            if cell.underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            let s = String(cell.ch) as NSString
            s.draw(at: CGPoint(x: rect.minX, y: rect.minY), withAttributes: attrs)
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
        let flags = event.modifierFlags
        if flags.contains(.command) {
            super.keyDown(with: event)   // let the main menu handle Cmd-shortcuts
            return
        }

        if flags.contains(.control) {
            handleControl(event)
            return
        }

        switch event.keyCode {
        case 36, 76:           // Return / Enter
            model.insertNewline()
        case 51:               // Delete (backspace)
            model.backspace()
        case 123: model.moveLeft()
        case 124: model.moveRight()
        case 125: model.moveDown()
        case 126: model.moveUp()
        default:
            insertPrintable(event)
        }
        refresh()
    }

    private func handleControl(_ event: NSEvent) {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "e": model.moveUp()
        case "x": model.moveDown()
        case "s": model.moveLeft()
        case "d": model.moveRight()
        default: break
        }
        refresh()
    }

    private func insertPrintable(_ event: NSEvent) {
        guard let chars = event.characters else { return }
        for ch in chars {
            guard let scalar = ch.unicodeScalars.first else { continue }
            if scalar.value >= 0x20 && scalar.value != 0x7f {
                model.insert(ch)
            }
        }
    }

    private func refresh() {
        renderGrid()
        updateCursorPosition(invalidateOld: true)
    }
}
