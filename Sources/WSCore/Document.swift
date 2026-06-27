import Foundation

/// A visual (on-screen) line: content is the half-open document range
/// `[start, end)`. The gap to the next line's start is 0 for a soft word-wrap
/// or 1 for a hard newline (the '\n' lives at `end`).
struct VisualLine: Equatable {
    var start: Int
    var end: Int
}

/// The editable document: a piece-table buffer plus a word-wrap layout cache and
/// a cursor. The cursor is a single linear offset; visual (line, column) is
/// derived from the layout. Word-wrap is computed at layout time (the buffer
/// stores only hard newlines), so margin changes and reformatting are cheap.
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

    private func syncPreferredColumn() { preferredColumn = cursorColumn }

    private func clampToLine(_ li: Int, _ col: Int) -> Int {
        let line = lines[li]
        let contentLen = line.end - line.start
        return line.start + min(col, contentLen)
    }

    // MARK: - Editing

    public func insertChar(_ ch: Character) {
        if !insertMode, cursor < count, pt.char(at: cursor) != "\n" {
            pt.delete(cursor..<(cursor + 1))
            pt.insert([ch], at: cursor)
            relayout(editStart: cursor, delta: 0)
        } else {
            pt.insert([ch], at: cursor)
            relayout(editStart: cursor, delta: 1)
        }
        cursor += 1
        syncPreferredColumn()
    }

    public func insertNewline() {
        pt.insert(["\n"], at: cursor)
        relayout(editStart: cursor, delta: 1)
        cursor += 1
        syncPreferredColumn()
    }

    public func backspace() {
        guard cursor > 0 else { return }
        pt.delete((cursor - 1)..<cursor)
        cursor -= 1
        relayout(editStart: cursor, delta: -1)
        syncPreferredColumn()
    }

    public func deleteForward() {
        guard cursor < count else { return }
        pt.delete(cursor..<(cursor + 1))
        relayout(editStart: cursor, delta: -1)
        syncPreferredColumn()
    }

    public func toggleInsertMode() { insertMode.toggle() }

    // MARK: - Cursor motion

    public func moveLeft()  { if cursor > 0 { cursor -= 1 }; syncPreferredColumn() }
    public func moveRight() { if cursor < count { cursor += 1 }; syncPreferredColumn() }

    public func moveUp() {
        let li = cursorLine
        if li > 0 { cursor = clampToLine(li - 1, preferredColumn) }
    }

    public func moveDown() {
        let li = cursorLine
        if li < lines.count - 1 { cursor = clampToLine(li + 1, preferredColumn) }
    }

    public func wordRight() {
        var o = cursor
        while o < count, !isWhitespace(pt.char(at: o)) { o += 1 }
        while o < count, isWhitespace(pt.char(at: o)) { o += 1 }
        cursor = o
        syncPreferredColumn()
    }

    public func wordLeft() {
        var o = cursor
        while o > 0, isWhitespace(pt.char(at: o - 1)) { o -= 1 }
        while o > 0, !isWhitespace(pt.char(at: o - 1)) { o -= 1 }
        cursor = o
        syncPreferredColumn()
    }

    public func lineStart() { cursor = lines[cursorLine].start; syncPreferredColumn() }
    public func lineEnd()   { cursor = lines[cursorLine].end;   syncPreferredColumn() }

    public func pageUp(rows: Int) {
        let target = max(0, cursorLine - max(1, rows))
        cursor = clampToLine(target, preferredColumn)
    }

    public func pageDown(rows: Int) {
        let target = min(lines.count - 1, cursorLine + max(1, rows))
        cursor = clampToLine(target, preferredColumn)
    }

    public func documentStart() { cursor = 0; syncPreferredColumn() }
    public func documentEnd()   { cursor = count; syncPreferredColumn() }

    private func isWhitespace(_ ch: Character) -> Bool {
        ch == " " || ch == "\n" || ch == "\t"
    }

    // MARK: - Layout (word wrap)

    func forceFullRelayout() {
        lines = wrapParagraphs(0, count)
        if lines.isEmpty { lines = [VisualLine(start: 0, end: 0)] }
    }

    /// Greedy word wrap over `[a, b)`, splitting on '\n' (hard) and the right
    /// margin (soft). Breaks after the space following a word so trailing spaces
    /// stay on the left line and every offset maps to exactly one line.
    private func wrapParagraphs(_ a: Int, _ b: Int) -> [VisualLine] {
        var result: [VisualLine] = []
        let chars = pt.slice(a..<b)
        let n = chars.count

        var curStart = a
        var lastBreak = -1   // absolute offset just after a candidate space
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
                    result.append(VisualLine(start: curStart, end: abs))   // hard-split long word
                    curStart = abs
                }
                lastBreak = -1
                continue   // re-evaluate this char against the new line
            }

            if ch == " " { lastBreak = abs + 1 }
            idx += 1
        }

        result.append(VisualLine(start: curStart, end: b))
        return result
    }

    /// Incremental relayout: re-wrap only the paragraph span touched by an edit
    /// and shift the offsets of following lines by `delta`. Equivalent to a full
    /// relayout (verified by tests) but bounded by paragraph size, not document
    /// size.
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
