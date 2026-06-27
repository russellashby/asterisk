import Foundation
@testable import WSCore

func runFormattingTests() {
    // Inline format toggles carry across soft-wrapped lines.
    do {
        let d = Document(wrapWidth: 8)
        // "AAAA" + bold-on + "BB CCCC" → bold turns on, then text wraps; the
        // continuation line should inherit bold in its entry attrs.
        for ch in "AAAA" { d.insertChar(ch) }
        d.insertFormat(.bold)
        for ch in "BB CCCC DDDD" { d.insertChar(ch) }
        check(d.lineCount >= 2, "formatted text wrapped")
        // First line entry has no attrs; a later line should be bold.
        eq(d.lineEntryAttrs(0).bold, false, "line 0 not bold at entry")
        var anyBoldEntry = false
        for i in 1..<d.lineCount where d.lineEntryAttrs(i).bold { anyBoldEntry = true }
        check(anyBoldEntry, "a wrapped continuation line inherits bold")
    }

    // Attributes reset at a hard newline.
    do {
        let d = Document(wrapWidth: 65)
        d.insertFormat(.bold)
        for ch in "bold" { d.insertChar(ch) }
        d.insertNewline()
        for ch in "plain" { d.insertChar(ch) }
        eq(d.lineEntryAttrs(1).bold, false, "bold resets after hard newline")
    }

    // Dot-command lines are recognised and not wrapped.
    do {
        let d = Document(wrapWidth: 65)
        for ch in ".rm 60" { d.insertChar(ch) }
        d.insertNewline()
        for ch in "hello" { d.insertChar(ch) }
        check(d.lineIsDot(0), "dot-command line flagged")
        check(!d.lineIsDot(1), "text line not flagged as dot")
        eq(String(d.lineText(0)), ".rm 60", "dot line content intact")
    }

    // A long dot line is not word-wrapped (stays one visual line).
    do {
        let d = Document(wrapWidth: 8)
        for ch in ".he a very long header line here" { d.insertChar(ch) }
        eq(d.lineCount, 1, "dot line never wraps")
        check(d.lineIsDot(0), "long dot line flagged")
    }

    // Incremental layout still equals full layout with control bytes + dots.
    do {
        var rng = SystemRandomNumberGenerator()
        let d = Document(wrapWidth: 10)
        let alphabet: [Character] = ["a", "b", " ", "c", "\n", ".", formatControlChar(.bold)]
        var diverged = false
        for _ in 0..<4000 where !diverged {
            let n = d.count
            if n == 0 || Bool.random(using: &rng) {
                cursorTo(d, Int.random(in: 0...n, using: &rng))
                let ch = alphabet.randomElement(using: &rng)!
                if ch == "\n" { d.insertNewline() } else { d.insertChar(ch) }
            } else {
                cursorTo(d, Int.random(in: 0..<n, using: &rng))
                d.deleteForward()
            }
            let incremental = d.lines
            d.forceFullRelayout()
            if incremental != d.lines { diverged = true }
        }
        check(!diverged, "incremental layout matches full (with formatting + dots)")
    }
}

private func cursorTo(_ d: Document, _ offset: Int) {
    while d.cursor > offset { d.moveLeft() }
    while d.cursor < offset { d.moveRight() }
}
