import Foundation
@testable import WSCore

func runCommandTests() {
    runCommandResolution()
    runBlockTests()
    runFindReplaceTests()
    runUndoTests()
}

private func runCommandResolution() {
    eq(resolveBlockCommand("b"), .markBlockBegin, "^KB")
    eq(resolveBlockCommand("K"), .markBlockEnd, "^KK (uppercase)")
    eq(resolveBlockCommand("c"), .copyBlock, "^KC")
    eq(resolveBlockCommand("v"), .moveBlock, "^KV")
    eq(resolveBlockCommand("y"), .deleteBlock, "^KY")
    check(resolveBlockCommand("z") == nil, "^Kz unknown")

    eq(resolveQuickCommand("s"), .lineStart, "^QS")
    eq(resolveQuickCommand("d"), .lineEnd, "^QD")
    eq(resolveQuickCommand("r"), .docStart, "^QR")
    eq(resolveQuickCommand("c"), .docEnd, "^QC")
    eq(resolveQuickCommand("f"), .find, "^QF")
    eq(resolveQuickCommand("a"), .findReplace, "^QA")
    check(resolveQuickCommand("z") == nil, "^Qz unknown")
}

private func makeDoc(_ s: String) -> Document {
    let d = Document(wrapWidth: 65)
    for ch in s { if ch == "\n" { d.insertNewline() } else { d.insertChar(ch) } }
    return d
}

private func runBlockTests() {
    // Mark, then delete a block.
    do {
        let d = makeDoc("hello world")
        // mark "world": begin at 6, end at 11
        d.documentStart(); for _ in 0..<6 { d.moveRight() }
        d.markBlockBegin()
        for _ in 0..<5 { d.moveRight() }
        d.markBlockEnd()
        eq(d.blockRange, 6..<11, "block range marked")
        d.deleteBlock()
        eq(d.text(), "hello ", "block deleted")
        check(d.blockRange == nil, "block cleared after delete")
    }

    // Copy block to cursor.
    do {
        let d = makeDoc("ab cd")
        d.documentStart(); d.markBlockBegin()
        d.moveRight(); d.moveRight()           // mark "ab"
        d.markBlockEnd()
        d.documentEnd()                         // cursor at end
        d.copyBlockAtCursor()
        eq(d.text(), "ab cdab", "block copied to cursor")
    }

    // Move block to cursor.
    do {
        let d = makeDoc("ab cd ")
        d.documentStart(); d.markBlockBegin()
        d.moveRight(); d.moveRight(); d.moveRight()   // mark "ab "
        d.markBlockEnd()
        d.documentEnd()                                // cursor at end (offset 6)
        d.moveBlock()
        eq(d.text(), "cd ab ", "block moved to end")
    }
}

private func runFindReplaceTests() {
    do {
        let d = makeDoc("the cat sat on the mat")
        d.documentStart()
        check(d.find(Array("cat")), "find cat")
        eq(d.cursor, 7, "cursor after 'cat'")
        check(d.find(Array("THE")), "find case-insensitive")
    }

    do {
        let d = makeDoc("aaa")
        d.documentStart()
        check(!d.find(Array("zzz")), "find missing returns false")
    }

    do {
        let d = makeDoc("one two one two one")
        d.documentStart()
        let n = d.replaceAll(Array("one"), with: Array("1"))
        eq(n, 3, "replace count")
        eq(d.text(), "1 two 1 two 1", "replace all result")
    }

    do {
        let d = makeDoc("foo bar foo")
        // cursor mid-document: replaceAll only affects from cursor onward
        d.documentStart(); for _ in 0..<4 { d.moveRight() }   // after "foo "
        let n = d.replaceAll(Array("foo"), with: Array("X"))
        eq(n, 1, "replace from cursor count")
        eq(d.text(), "foo bar X", "replace from cursor result")
    }
}

private func runUndoTests() {
    // Typing run is a single undo step.
    do {
        let d = makeDoc("")
        for ch in "hello" { d.insertChar(ch) }
        eq(d.text(), "hello", "typed text")
        d.undo()
        eq(d.text(), "", "undo whole typing run")
        d.redo()
        eq(d.text(), "hello", "redo typing run")
    }

    // Separate actions are separate undo steps.
    do {
        let d = makeDoc("ab")
        d.insertNewline()
        for ch in "cd" { d.insertChar(ch) }
        eq(d.text(), "ab\ncd", "after edits")
        d.undo()                     // undo "cd"
        eq(d.text(), "ab\n", "undo typing")
        d.undo()                     // undo newline
        eq(d.text(), "ab", "undo newline")
    }

    // Undo a block delete.
    do {
        let d = makeDoc("hello world")
        d.documentStart(); for _ in 0..<6 { d.moveRight() }
        d.markBlockBegin(); for _ in 0..<5 { d.moveRight() }; d.markBlockEnd()
        d.deleteBlock()
        eq(d.text(), "hello ", "block deleted")
        d.undo()
        eq(d.text(), "hello world", "undo restores block")
    }

    // Undo a replace-all in one step.
    do {
        let d = makeDoc("a a a")
        d.documentStart()
        _ = d.replaceAll(Array("a"), with: Array("bb"))
        eq(d.text(), "bb bb bb", "replaced")
        d.undo()
        eq(d.text(), "a a a", "undo replace-all in one step")
    }
}
