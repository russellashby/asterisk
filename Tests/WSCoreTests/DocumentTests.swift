import Foundation
@testable import WSCore

func runDocumentTests() {
    // Basic typing
    do {
        let doc = Document(wrapWidth: 65)
        for ch in "hello" { doc.insertChar(ch) }
        eq(doc.text(), "hello", "basic typing text")
        eq(doc.cursor, 5, "basic typing cursor")
        eq(doc.cursorLine, 0, "basic typing line")
        eq(doc.cursorColumn, 5, "basic typing column")
    }

    // Newlines split visual lines
    do {
        let doc = Document(wrapWidth: 65)
        for ch in "ab\ncd" { doc.insertChar(ch) }
        eq(doc.lineCount, 2, "newline line count")
        eq(String(doc.lineText(0)), "ab", "newline line 0")
        eq(String(doc.lineText(1)), "cd", "newline line 1")
    }

    // Word wrap
    do {
        let doc = Document(wrapWidth: 10)
        for ch in "the quick brown fox" { doc.insertChar(ch) }
        check(doc.lineCount >= 2, "word wrap produced multiple lines")
        for i in 0..<doc.lineCount {
            check(doc.lineText(i).count <= 10, "line \(i) within wrap width")
        }
        let joined = (0..<doc.lineCount).map { String(doc.lineText($0)) }.joined()
        eq(joined, "the quick brown fox", "word wrap reassembles text")
    }

    // Backspace merges lines
    do {
        let doc = Document(wrapWidth: 65)
        for ch in "ab" { doc.insertChar(ch) }
        doc.insertNewline()
        for ch in "cd" { doc.insertChar(ch) }
        eq(doc.lineCount, 2, "before merge line count")
        doc.backspace(); doc.backspace(); doc.backspace()
        eq(doc.text(), "ab", "backspace merge text")
        eq(doc.lineCount, 1, "backspace merge line count")
    }

    // Overtype mode
    do {
        let doc = Document(wrapWidth: 65)
        for ch in "abcd" { doc.insertChar(ch) }
        doc.documentStart()
        doc.insertMode = false
        doc.insertChar("X"); doc.insertChar("Y")
        eq(doc.text(), "XYcd", "overtype replaces chars")
    }

    // Vertical motion keeps preferred column
    do {
        let doc = Document(wrapWidth: 65)
        for ch in "long line one" { doc.insertChar(ch) }
        doc.insertNewline()
        for ch in "hi" { doc.insertChar(ch) }
        doc.insertNewline()
        for ch in "another long line" { doc.insertChar(ch) }
        doc.moveUp()
        eq(doc.cursorLine, 1, "vmotion onto short line")
        eq(doc.cursorColumn, 2, "vmotion clamped to short line")
        doc.moveUp()
        eq(doc.cursorLine, 0, "vmotion onto long line")
        eq(doc.cursorColumn, 13, "vmotion restored preferred column")
    }

    // Word motion
    do {
        let doc = Document(wrapWidth: 65)
        for ch in "the quick brown" { doc.insertChar(ch) }
        doc.documentStart()
        doc.wordRight(); eq(doc.cursorColumn, 4, "wordRight to quick")
        doc.wordRight(); eq(doc.cursorColumn, 10, "wordRight to brown")
        doc.wordLeft();  eq(doc.cursorColumn, 4, "wordLeft back to quick")
    }

    // Incremental layout must equal full layout under random edits
    do {
        var rng = SystemRandomNumberGenerator()
        let doc = Document(wrapWidth: 12)
        let alphabet = Array("ab cd ef\n")
        var diverged = false
        for _ in 0..<3000 where !diverged {
            let n = doc.count
            if n == 0 || Bool.random(using: &rng) {
                doc.cursorSet(Int.random(in: 0...n, using: &rng))
                let ch = alphabet.randomElement(using: &rng)!
                if ch == "\n" { doc.insertNewline() } else { doc.insertChar(ch) }
            } else {
                doc.cursorSet(Int.random(in: 0..<n, using: &rng))
                doc.deleteForward()
            }
            let incremental = doc.lines
            doc.forceFullRelayout()
            if incremental != doc.lines { diverged = true }
        }
        check(!diverged, "incremental layout matches full layout")
    }
}

// Test-only convenience.
extension Document {
    func cursorSet(_ offset: Int) {
        while cursor > offset { moveLeft() }
        while cursor < offset { moveRight() }
    }
}
