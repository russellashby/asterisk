import Foundation
@testable import WSCore

private func type(_ d: Document, _ s: String) {
    for ch in s { if ch == "\n" { d.insertNewline() } else { d.insertChar(ch) } }
}

func runJustifyTests() {
    // A soft-wrapped line is padded so its last word reaches the right margin.
    do {
        let d = Document(wrapWidth: 10)            // justify on by default
        type(d, "aaa bbb ccc ddd")                // wraps at width 10
        check(d.lineCount >= 2, "text wrapped for justification")
        guard let cols = d.justifiedColumns(0) else { check(false, "line 0 should justify"); return }
        let chars = Array(String(d.lineText(0)))
        // index of the last non-space character on the (trimmed) line
        var last = chars.count - 1
        while last >= 0, chars[last] == " " { last -= 1 }
        eq(cols[last], 9, "justified last char reaches right margin (width-1)")
        eq(cols[0], 0, "justified line starts at column 0")
        // columns are non-decreasing
        var monotone = true
        for k in 1..<cols.count where cols[k] < cols[k - 1] { monotone = false }
        check(monotone, "justified columns are non-decreasing")
    }

    // The last line of a paragraph is NOT justified (stays ragged).
    do {
        let d = Document(wrapWidth: 10)
        type(d, "aaa bbb ccc ddd")
        let lastLine = d.lineCount - 1
        check(d.justifiedColumns(lastLine) == nil, "paragraph's last line is ragged")
    }

    // A hard newline ends the paragraph; that line is ragged even if long.
    do {
        let d = Document(wrapWidth: 12)
        type(d, "one two\nthree four")
        check(d.justifiedColumns(0) == nil, "line ended by newline is not justified")
    }

    // Justify off → no line is justified.
    do {
        let d = Document(wrapWidth: 10)
        type(d, "aaa bbb ccc ddd")
        d.toggleJustify()
        check(!d.justify, "toggle turned justify off")
        for i in 0..<d.lineCount { check(d.justifiedColumns(i) == nil, "no justification when off (line \(i))") }
        d.toggleJustify()
        check(d.justify, "toggle restored justify")
    }

    // A single long word has no gaps to widen → not justified.
    do {
        let d = Document(wrapWidth: 5)
        type(d, "aaaaaaaaaaaa")                    // one word, force-split
        for i in 0..<d.lineCount { check(d.justifiedColumns(i) == nil, "single-word line not justified (line \(i))") }
    }
}
