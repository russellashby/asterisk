import Foundation
@testable import WSCore

private func type(_ d: Document, _ s: String) {
    for ch in s { if ch == "\n" { d.insertNewline() } else { d.insertChar(ch) } }
}

/// Longest non-dot visual line (content length), for asserting wrap widths.
private func widestText(_ d: Document) -> Int {
    var w = 0
    for i in 0..<d.lineCount where !d.lineIsDot(i) { w = max(w, d.lineText(i).count) }
    return w
}

func runMarginTests() {
    // .lm sets the left indent of following text (1-based → leftIndent = lm-1).
    do {
        let d = Document(wrapWidth: 65)
        type(d, ".lm 5\nhello")
        check(d.lineIsDot(0), "lm: line 0 is the dot command")
        eq(d.lineLeftIndent(1), 4, "lm 5 → leftIndent 4 on following text")
    }

    // .rm narrows the wrap region for following text.
    do {
        let d = Document(wrapWidth: 65)
        type(d, ".rm 10\n")
        type(d, "aaaa bbbb cccc dddd eeee")
        check(widestText(d) <= 10, "rm 10 wraps within width 10 (got \(widestText(d)))")
        check(d.lineCount >= 3, "rm 10 long text wrapped into multiple lines")
    }

    // Two regions: a later .rm widens the wrap region again.
    do {
        let narrow = Document(wrapWidth: 65)
        type(narrow, ".rm 10\nfoo bar baz qux quux corge grault garply waldo fred plugh\n")
        let narrowWidest = widestText(narrow)

        let wide = Document(wrapWidth: 65)
        type(wide, ".rm 10\nfoo bar baz qux\n.rm 70\nfoo bar baz qux quux corge grault garply waldo fred plugh\n")
        check(widestText(wide) > narrowWidest,
              "second region (.rm 70) wraps wider than .rm 10 (\(widestText(wide)) > \(narrowWidest))")
    }

    // Editing within a margin region keeps offsets/cursor and indent correct.
    do {
        let d = Document(wrapWidth: 65)
        type(d, ".lm 5\nhello world")
        d.documentStart()
        d.moveDown()                       // onto the text line
        eq(d.lineLeftIndent(d.cursorLine), 4, "edit region indent is 4")
        type(d, "X")                       // insert at start of the text line
        check(d.cursor <= d.count, "cursor within bounds after edit")
        eq(d.lineLeftIndent(d.cursorLine), 4, "indent persists after edit in region")
        eq(String(d.lineText(d.cursorLine)).first, "X", "inserted char landed in the line")
    }

    // .pa forces a page break before the next text line.
    do {
        let d = Document(wrapWidth: 65)
        type(d, "para one\n.pa\npara two")
        // lines: 0 = "para one", 1 = ".pa" (dot), 2 = "para two"
        check(d.pageBreakBeforeLine.contains(2),
              "pa breaks before next text line; breaks = \(d.pageBreakBeforeLine)")
    }

    // Automatic pagination from a small .pl: a break every `cap` text lines.
    do {
        let d = Document(wrapWidth: 65)
        type(d, ".pl 8\n.mt 0\n.mb 0\n")     // cap = 8 - 0 - 0 = 8
        for _ in 0..<20 { type(d, "x\n") }
        let b = d.pageBreakBeforeLine
        check(b.count >= 2, "small pl produces multiple breaks; \(b)")
        if b.count >= 2 { eq(b[1] - b[0], 8, "breaks fall 8 text lines apart") }
    }

    // Dot lines don't count toward the page; the 9th *text* line breaks.
    do {
        let d = Document(wrapWidth: 65)
        type(d, ".pl 8\n.mt 0\n.mb 0\n")     // cap = 8
        for _ in 0..<8 { type(d, "t\n") }    // exactly fills the page
        type(d, ".lm 1\n")                   // a dot line — must not count
        type(d, "next\n")                    // 9th text line → break before it
        var nextIdx = -1
        for i in 0..<d.lineCount where !d.lineIsDot(i) && String(d.lineText(i)) == "next" { nextIdx = i }
        check(d.pageBreakBeforeLine.contains(nextIdx),
              "dot lines don't fill the page; break before 'next' (idx \(nextIdx)); breaks = \(d.pageBreakBeforeLine)")
    }

    // No dot commands → no page breaks even for a long document.
    do {
        let d = Document(wrapWidth: 65)
        for _ in 0..<200 { type(d, "line\n") }
        check(d.pageBreakBeforeLine.isEmpty, "dotless document shows no page breaks")
    }
}
