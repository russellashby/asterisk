import Foundation

/// A deliberately simple line-based text model for Phase 1, just enough to type
/// and move the cursor so we can measure input latency. This will be replaced
/// by a piece table in Phase 2.
final class TextModel {
    var lines: [[Character]] = [[]]
    var cy = 0   // cursor line
    var cx = 0   // cursor column

    var currentLineCount: Int { lines[cy].count }

    func insert(_ ch: Character) {
        lines[cy].insert(ch, at: cx)
        cx += 1
    }

    func insertNewline() {
        let tail = Array(lines[cy][cx...])
        lines[cy].removeSubrange(cx...)
        lines.insert(tail, at: cy + 1)
        cy += 1
        cx = 0
    }

    func backspace() {
        if cx > 0 {
            lines[cy].remove(at: cx - 1)
            cx -= 1
        } else if cy > 0 {
            let prevLen = lines[cy - 1].count
            lines[cy - 1].append(contentsOf: lines[cy])
            lines.remove(at: cy)
            cy -= 1
            cx = prevLen
        }
    }

    // MARK: - Cursor diamond (^E ^X ^S ^D) and arrows

    func moveLeft() {
        if cx > 0 { cx -= 1 }
        else if cy > 0 { cy -= 1; cx = lines[cy].count }
    }

    func moveRight() {
        if cx < lines[cy].count { cx += 1 }
        else if cy < lines.count - 1 { cy += 1; cx = 0 }
    }

    func moveUp() {
        if cy > 0 { cy -= 1; cx = min(cx, lines[cy].count) }
    }

    func moveDown() {
        if cy < lines.count - 1 { cy += 1; cx = min(cx, lines[cy].count) }
    }
}
