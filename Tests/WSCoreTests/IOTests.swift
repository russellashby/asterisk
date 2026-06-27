import Foundation
@testable import WSCore

func runIOTests() {
    // Save → load round-trip preserves text, control bytes and dot lines.
    do {
        let d = Document(wrapWidth: 65)
        for ch in ".rm 60" { d.insertChar(ch) }
        d.insertNewline()
        for ch in "Hello " { d.insertChar(ch) }
        d.insertFormat(.bold)
        for ch in "world" { d.insertChar(ch) }
        d.insertFormat(.bold)
        d.insertNewline()
        for ch in "second line" { d.insertChar(ch) }

        let saved = d.text()
        let loaded = Document(text: saved, wrapWidth: 65)

        eq(loaded.text(), saved, "round-trip text identical")
        eq(loaded.lineCount, d.lineCount, "round-trip line count")
        check(loaded.lineIsDot(0), "round-trip preserved dot line")
        // The bold control bytes survived (two of them).
        let boldCount = saved.filter { $0 == formatControlChar(.bold) }.count
        eq(boldCount, 2, "round-trip preserved bold control bytes")
    }

    // Actual on-disk round-trip through a real UTF-8 file (control bytes too).
    do {
        let d = Document(wrapWidth: 65)
        for ch in "Bold: " { d.insertChar(ch) }
        d.insertFormat(.bold); for ch in "X" { d.insertChar(ch) }; d.insertFormat(.bold)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ws_iotest_\(UUID().uuidString).WS")
        do {
            try d.text().write(to: url, atomically: true, encoding: .utf8)
            let data = try Data(contentsOf: url)
            let reread = String(data: data, encoding: .utf8) ?? ""
            eq(reread, d.text(), "on-disk round-trip identical")
            try? FileManager.default.removeItem(at: url)
        } catch {
            check(false, "on-disk round-trip threw: \(error)")
        }
    }

    // Revision tracking for dirty state.
    do {
        let d = Document(text: "preloaded", wrapWidth: 65)
        eq(d.revision, 0, "loaded document starts at revision 0")
        d.insertChar("x")
        check(d.revision != 0, "editing bumps revision")
        let r = d.revision
        d.undo()
        check(d.revision != r, "undo also bumps revision")
    }
}
