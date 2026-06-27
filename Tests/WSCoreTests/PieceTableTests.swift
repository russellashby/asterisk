@testable import WSCore

func runPieceTableTests() {
    // Insert / append
    do {
        let pt = PieceTable()
        pt.insert(Array("Hello"), at: 0)
        pt.insert(Array(", world"), at: 5)
        eq(pt.text(), "Hello, world", "insert append text")
        eq(pt.count, 12, "insert append count")
    }

    // Insert in the middle
    do {
        let pt = PieceTable(text: "Helloworld")
        pt.insert(Array(", "), at: 5)
        eq(pt.text(), "Hello, world", "insert middle")
    }

    // Delete
    do {
        let pt = PieceTable(text: "Hello, world")
        pt.delete(5..<7)
        eq(pt.text(), "Helloworld", "delete range")
        pt.delete(0..<5)
        eq(pt.text(), "world", "delete prefix")
    }

    // Slice + char access across pieces
    do {
        let pt = PieceTable(text: "abcdef")
        pt.insert(Array("XYZ"), at: 3)   // abcXYZdef
        eq(String(pt.slice(2..<6)), "cXYZ", "slice across pieces")
        eq(pt.char(at: 0), "a", "char first")
        eq(pt.char(at: 3), "X", "char in add piece")
        eq(pt.char(at: 8), "f", "char last")
    }

    // Contiguous typing coalesces into few pieces
    do {
        let pt = PieceTable()
        for (i, ch) in "abcdef".enumerated() { pt.insert([ch], at: i) }
        eq(pt.text(), "abcdef", "contiguous typing")
    }

    // Randomized vs reference String
    do {
        var rng = SystemRandomNumberGenerator()
        let pt = PieceTable()
        var ref = ""
        let alphabet = Array("ab cd\nef")
        for _ in 0..<2000 {
            if ref.isEmpty || Bool.random(using: &rng) {
                let pos = Int.random(in: 0...ref.count, using: &rng)
                let ch = alphabet.randomElement(using: &rng)!
                pt.insert([ch], at: pos)
                ref.insert(ch, at: ref.index(ref.startIndex, offsetBy: pos))
            } else {
                let pos = Int.random(in: 0..<ref.count, using: &rng)
                pt.delete(pos..<(pos + 1))
                ref.remove(at: ref.index(ref.startIndex, offsetBy: pos))
            }
        }
        eq(pt.text(), ref, "randomized piece table vs reference")
    }
}
