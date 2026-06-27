import Foundation

/// A visual (on-screen) line: content is the half-open document range
/// `[start, end)`. The gap to the next line's start is 0 for a soft word-wrap
/// or 1 for a hard newline (the '\n' lives at `end`).
struct VisualLine: Equatable {
    var start: Int
    var end: Int
}

/// The editable document: a piece-table buffer plus a word-wrap layout cache, a
/// cursor, block marks, search state and undo/redo. The cursor is a single
/// linear offset; visual (line, column) is derived from the layout. Word-wrap is
/// computed at layout time (the buffer stores only hard newlines).
///
/// AppKit-free and unit tested; the view layer talks to this.
public final class Document {

    private let pt: PieceTable
    private(set) var lines: [VisualLine] = [VisualLine(start: 0, end: 0)]

    public var wrapWidth: Int {
        didSet { if wrapWidth < 1 { wrapWidth = 1 }; forceFullRelayout() }
    }
    public var insertMode = true

    private(set) public var cursor = 0      // offset 0...count
    private var preferredColumn = 0

    // Block marks (document offsets) and highlight visibility.
    public private(set) var blockBegin: Int?
    public private(set) var blockEnd: Int?
    public private(set) var blockHidden = false

    // Search state for "find next".
    private var lastSearch: [Character]?
    private var lastCaseInsensitive = true

    // Undo/redo as document-state snapshots, with typing coalesced into one run.
    private struct DocState {
        var pieces: [PieceTable.Piece]
        var count: Int
        var cursor: Int
        var blockBegin: Int?
        var blockEnd: Int?
    }
    private var undoStack: [DocState] = []
    private var redoStack: [DocState] = []
    private var typingRun = false
    private let undoLimit = 400

    public init(text: String = "", wrapWidth: Int = 65) {
        self.pt = PieceTable(text: text)
        self.wrapWidth = max(1, wrapWidth)
        forceFullRelayout()
    }

    public var count: Int { pt.count }
    public var lineCount: Int { lines.count }
    public func text() -> String { pt.text() }

    // MARK: - Cursor position (derived)

    public var cursorLine: Int { lineIndex(of: cursor) }
    public var cursorColumn: Int { cursor - lines[cursorLine].start }

    func lineIndex(of offset: Int) -> Int {
        var lo = 0, hi = lines.count - 1, ans = 0
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lines[mid].start <= offset { ans = mid; lo = mid + 1 }
            else { hi = mid - 1 }
        }
        return ans
    }

    /// Content of a visual line (without any trailing newline), for rendering.
    public func lineText(_ index: Int) -> [Character] {
        let l = lines[index]
        return pt.slice(l.start..<l.end)
    }

    /// Document offset of the first character of a visual line (for highlight).
    public func lineStartOffset(_ index: Int) -> Int { lines[index].start }

    public var blockRange: Range<Int>? {
        guard let b = blockBegin, let e = blockEnd else { return nil }
        let lo = min(b, e), hi = max(b, e)
        return lo < hi ? lo..<hi : nil
    }

    private func syncPreferredColumn() { preferredColumn = cursorColumn }
    private func endTyping() { typingRun = false }

    private func clampToLine(_ li: Int, _ col: Int) -> Int {
        let line = lines[li]
        let contentLen = line.end - line.start
        return line.start + min(col, contentLen)
    }

    private func isWhitespace(_ ch: Character) -> Bool {
        ch == " " || ch == "\n" || ch == "\t"
    }

    // MARK: - Low-level edit primitives (buffer + layout + mark tracking)

    private func rawInsert(_ chars: [Character], at offset: Int) {
        pt.insert(chars, at: offset)
        relayout(editStart: offset, delta: chars.count)
        if let b = blockBegin, b > offset { blockBegin = b + chars.count }
        if let e = blockEnd, e > offset { blockEnd = e + chars.count }
    }

    private func rawDelete(_ range: Range<Int>) {
        pt.delete(range)
        relayout(editStart: range.lowerBound, delta: -range.count)
        blockBegin = shiftForDelete(blockBegin, range)
        blockEnd = shiftForDelete(blockEnd, range)
    }

    private func shiftForDelete(_ mark: Int?, _ range: Range<Int>) -> Int? {
        guard let m = mark else { return nil }
        if m <= range.lowerBound { return m }
        if m >= range.upperBound { return m - range.count }
        return range.lowerBound
    }

    // MARK: - Editing

    public func insertChar(_ ch: Character) {
        if !typingRun { pushUndo(); typingRun = true }
        if !insertMode, cursor < count, pt.char(at: cursor) != "\n" {
            rawDelete(cursor..<(cursor + 1))
            rawInsert([ch], at: cursor)
        } else {
            rawInsert([ch], at: cursor)
        }
        cursor += 1
        syncPreferredColumn()
    }

    public func insertNewline() {
        endTyping(); pushUndo()
        rawInsert(["\n"], at: cursor)
        cursor += 1
        syncPreferredColumn()
    }

    public func backspace() {
        guard cursor > 0 else { return }
        endTyping(); pushUndo()
        rawDelete((cursor - 1)..<cursor)
        cursor -= 1
        syncPreferredColumn()
    }

    public func deleteForward() {
        guard cursor < count else { return }
        endTyping(); pushUndo()
        rawDelete(cursor..<(cursor + 1))
        syncPreferredColumn()
    }

    public func toggleInsertMode() { endTyping(); insertMode.toggle() }

    /// ^QY — delete from the cursor to the end of the logical line.
    public func deleteToLineEnd() {
        endTyping()
        var e = cursor
        while e < count, pt.char(at: e) != "\n" { e += 1 }
        guard e > cursor else { return }
        pushUndo()
        rawDelete(cursor..<e)
        syncPreferredColumn()
    }

    /// ^Y — delete the whole current visual line (content + its line break).
    public func deleteLine() {
        endTyping()
        let li = cursorLine
        let start = lines[li].start
        let end = (li + 1 < lines.count) ? lines[li + 1].start : count
        guard end > start else { return }
        pushUndo()
        rawDelete(start..<end)
        cursor = min(start, count)
        syncPreferredColumn()
    }

    /// ^T — delete the word to the right of the cursor.
    public func deleteWordRight() {
        endTyping()
        let target = wordRightOffset(from: cursor)
        guard target > cursor else { return }
        pushUndo()
        rawDelete(cursor..<target)
        syncPreferredColumn()
    }

    // MARK: - Cursor motion

    public func moveLeft()  { endTyping(); if cursor > 0 { cursor -= 1 }; syncPreferredColumn() }
    public func moveRight() { endTyping(); if cursor < count { cursor += 1 }; syncPreferredColumn() }

    public func moveUp() {
        endTyping()
        let li = cursorLine
        if li > 0 { cursor = clampToLine(li - 1, preferredColumn) }
    }

    public func moveDown() {
        endTyping()
        let li = cursorLine
        if li < lines.count - 1 { cursor = clampToLine(li + 1, preferredColumn) }
    }

    private func wordRightOffset(from offset: Int) -> Int {
        var o = offset
        while o < count, !isWhitespace(pt.char(at: o)) { o += 1 }
        while o < count, isWhitespace(pt.char(at: o)) { o += 1 }
        return o
    }

    public func wordRight() { endTyping(); cursor = wordRightOffset(from: cursor); syncPreferredColumn() }

    public func wordLeft() {
        endTyping()
        var o = cursor
        while o > 0, isWhitespace(pt.char(at: o - 1)) { o -= 1 }
        while o > 0, !isWhitespace(pt.char(at: o - 1)) { o -= 1 }
        cursor = o
        syncPreferredColumn()
    }

    public func lineStart() { endTyping(); cursor = lines[cursorLine].start; syncPreferredColumn() }
    public func lineEnd()   { endTyping(); cursor = lines[cursorLine].end;   syncPreferredColumn() }

    public func pageUp(rows: Int) {
        endTyping()
        cursor = clampToLine(max(0, cursorLine - max(1, rows)), preferredColumn)
    }

    public func pageDown(rows: Int) {
        endTyping()
        cursor = clampToLine(min(lines.count - 1, cursorLine + max(1, rows)), preferredColumn)
    }

    public func documentStart() { endTyping(); cursor = 0; syncPreferredColumn() }
    public func documentEnd()   { endTyping(); cursor = count; syncPreferredColumn() }

    // MARK: - Block operations (^K)

    public func markBlockBegin() { endTyping(); blockBegin = cursor }
    public func markBlockEnd()   { endTyping(); blockEnd = cursor }
    public func toggleBlockHidden() { endTyping(); blockHidden.toggle() }
    private func clearBlock() { blockBegin = nil; blockEnd = nil }

    public func toBlockBegin() {
        endTyping()
        if let b = blockBegin { cursor = min(b, count); syncPreferredColumn() }
    }

    public func toBlockEnd() {
        endTyping()
        if let e = blockEnd { cursor = min(e, count); syncPreferredColumn() }
    }

    /// ^KC — copy the marked block to the cursor position.
    public func copyBlockAtCursor() {
        guard let r = blockRange else { return }
        endTyping(); pushUndo()
        let txt = pt.slice(r)
        let at = cursor
        rawInsert(txt, at: at)
        cursor = min(at + txt.count, count)
        clearBlock()
        syncPreferredColumn()
    }

    /// ^KV — move the marked block to the cursor position.
    public func moveBlock() {
        guard let r = blockRange else { return }
        endTyping(); pushUndo()
        let txt = pt.slice(r)
        var at = cursor
        if at >= r.upperBound { at -= r.count }
        else if at > r.lowerBound { at = r.lowerBound }   // cursor inside block
        rawDelete(r)
        rawInsert(txt, at: at)
        cursor = at + txt.count
        clearBlock()
        syncPreferredColumn()
    }

    /// ^KY — delete the marked block.
    public func deleteBlock() {
        guard let r = blockRange else { return }
        endTyping(); pushUndo()
        rawDelete(r)
        cursor = r.lowerBound
        clearBlock()
        syncPreferredColumn()
    }

    // MARK: - Find / replace

    /// ^QF — find `needle` from the cursor (wrapping). Returns whether found.
    @discardableResult
    public func find(_ needle: [Character], caseInsensitive: Bool = true) -> Bool {
        endTyping()
        lastSearch = needle
        lastCaseInsensitive = caseInsensitive
        guard !needle.isEmpty else { return false }
        let hay = pt.slice(0..<count)
        if let r = Document.search(hay, needle, from: cursor, ci: caseInsensitive) {
            cursor = r.upperBound; syncPreferredColumn(); return true
        }
        if let r = Document.search(hay, needle, from: 0, ci: caseInsensitive) {
            cursor = r.upperBound; syncPreferredColumn(); return true
        }
        return false
    }

    /// ^L — repeat the last find from the cursor.
    @discardableResult
    public func findNext() -> Bool {
        guard let n = lastSearch else { return false }
        return find(n, caseInsensitive: lastCaseInsensitive)
    }

    /// ^QA — replace all occurrences of `needle` from the cursor to the end of
    /// the document. Returns the number replaced (one undo step).
    @discardableResult
    public func replaceAll(_ needle: [Character], with replacement: [Character],
                           caseInsensitive: Bool = true) -> Int {
        endTyping()
        guard !needle.isEmpty else { return 0 }
        let hay = pt.slice(0..<count)
        var matches: [Range<Int>] = []
        var from = cursor
        while let r = Document.search(hay, needle, from: from, ci: caseInsensitive) {
            matches.append(r)
            from = r.upperBound
        }
        guard !matches.isEmpty else { return 0 }
        pushUndo()
        for r in matches.reversed() {
            rawDelete(r)
            rawInsert(replacement, at: r.lowerBound)
        }
        cursor = min(cursor, count)
        syncPreferredColumn()
        return matches.count
    }

    static func search(_ hay: [Character], _ needle: [Character], from: Int, ci: Bool) -> Range<Int>? {
        let n = hay.count, m = needle.count
        if m == 0 || m > n { return nil }
        let nd = ci ? needle.map(wsLower) : needle
        var i = max(0, from)
        while i + m <= n {
            var k = 0
            while k < m {
                let hc = ci ? wsLower(hay[i + k]) : hay[i + k]
                if hc != nd[k] { break }
                k += 1
            }
            if k == m { return i..<(i + m) }
            i += 1
        }
        return nil
    }

    // MARK: - Undo / redo

    private func captureState() -> DocState {
        let snap = pt.snapshot()
        return DocState(pieces: snap.pieces, count: snap.count,
                        cursor: cursor, blockBegin: blockBegin, blockEnd: blockEnd)
    }

    private func pushUndo() {
        undoStack.append(captureState())
        if undoStack.count > undoLimit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func apply(_ s: DocState) {
        pt.restore(pieces: s.pieces, count: s.count)
        cursor = min(s.cursor, s.count)
        blockBegin = s.blockBegin
        blockEnd = s.blockEnd
        forceFullRelayout()
        syncPreferredColumn()
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func undo() {
        endTyping()
        guard let s = undoStack.popLast() else { return }
        redoStack.append(captureState())
        apply(s)
    }

    public func redo() {
        endTyping()
        guard let s = redoStack.popLast() else { return }
        undoStack.append(captureState())
        apply(s)
    }

    // MARK: - Layout (word wrap)

    func forceFullRelayout() {
        lines = wrapParagraphs(0, count)
        if lines.isEmpty { lines = [VisualLine(start: 0, end: 0)] }
        if cursor > count { cursor = count }
    }

    /// Greedy word wrap over `[a, b)`, splitting on '\n' (hard) and the right
    /// margin (soft). Breaks after the space following a word so trailing spaces
    /// stay on the left line and every offset maps to exactly one line.
    private func wrapParagraphs(_ a: Int, _ b: Int) -> [VisualLine] {
        var result: [VisualLine] = []
        let chars = pt.slice(a..<b)
        let n = chars.count

        var curStart = a
        var lastBreak = -1
        var idx = 0
        while idx < n {
            let ch = chars[idx]
            let abs = a + idx

            if ch == "\n" {
                result.append(VisualLine(start: curStart, end: abs))
                curStart = abs + 1
                lastBreak = -1
                idx += 1
                continue
            }

            let lineLen = abs - curStart + 1
            if lineLen > wrapWidth {
                if lastBreak > curStart {
                    result.append(VisualLine(start: curStart, end: lastBreak))
                    curStart = lastBreak
                } else {
                    result.append(VisualLine(start: curStart, end: abs))
                    curStart = abs
                }
                lastBreak = -1
                continue
            }

            if ch == " " { lastBreak = abs + 1 }
            idx += 1
        }

        result.append(VisualLine(start: curStart, end: b))
        return result
    }

    /// Incremental relayout: re-wrap only the paragraph span touched by an edit
    /// and shift the offsets of following lines by `delta`. Verified equivalent
    /// to a full relayout by tests, but bounded by paragraph size.
    private func relayout(editStart: Int, delta: Int) {
        let newCount = count

        var paraStart = editStart
        while paraStart > 0, pt.char(at: paraStart - 1) != "\n" { paraStart -= 1 }

        var rightAnchor = editStart + max(delta, 0)
        if rightAnchor > newCount { rightAnchor = newCount }
        var paraEnd = rightAnchor
        while paraEnd < newCount, pt.char(at: paraEnd) != "\n" { paraEnd += 1 }

        let mid = wrapParagraphs(paraStart, paraEnd)
        let paraEndOld = paraEnd - delta

        var prefix: [VisualLine] = []
        var k = 0
        while k < lines.count, lines[k].start < paraStart {
            prefix.append(lines[k]); k += 1
        }

        var m = k
        while m < lines.count, lines[m].start <= paraEndOld { m += 1 }

        var suffix: [VisualLine] = []
        while m < lines.count {
            suffix.append(VisualLine(start: lines[m].start + delta,
                                     end: lines[m].end + delta))
            m += 1
        }

        lines = prefix + mid + suffix
        if lines.isEmpty { lines = [VisualLine(start: 0, end: 0)] }
    }
}
