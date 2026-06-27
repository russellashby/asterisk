import Foundation

/// A piece table: the document is a sequence of "pieces" pointing into either an
/// immutable `original` buffer (loaded text) or an append-only `add` buffer
/// (everything typed). Inserts never copy bulk text; deletes only re-slice
/// pieces. This is the edit buffer that replaces Phase 1's line array.
///
/// Offsets are grapheme (Character) counts — natural for a text editor cursor.
final class PieceTable {

    enum Source { case original, add }

    struct Piece {
        var source: Source
        var start: Int      // index into the source buffer
        var length: Int
    }

    private let original: [Character]
    private var add: [Character] = []
    private var pieces: [Piece] = []
    private(set) var count: Int = 0

    init(text: String = "") {
        original = Array(text)
        if !original.isEmpty {
            pieces.append(Piece(source: .original, start: 0, length: original.count))
            count = original.count
        }
    }

    private func buffer(_ s: Source) -> [Character] {
        s == .original ? original : add
    }

    // MARK: - Reading

    func char(at offset: Int) -> Character {
        var rem = offset
        for p in pieces {
            if rem < p.length { return buffer(p.source)[p.start + rem] }
            rem -= p.length
        }
        return "\n"   // out-of-range guard (treated as a boundary)
    }

    /// Extract a contiguous range in one pass over the pieces.
    func slice(_ range: Range<Int>) -> [Character] {
        guard !range.isEmpty else { return [] }
        var result: [Character] = []
        result.reserveCapacity(range.count)
        var pos = 0
        for p in pieces {
            let pStart = pos
            let pEnd = pos + p.length
            if pEnd <= range.lowerBound { pos = pEnd; continue }
            if pStart >= range.upperBound { break }
            let from = max(range.lowerBound, pStart) - pStart
            let to = min(range.upperBound, pEnd) - pStart
            let buf = buffer(p.source)
            result.append(contentsOf: buf[(p.start + from)..<(p.start + to)])
            pos = pEnd
        }
        return result
    }

    func text() -> String { String(slice(0..<count)) }

    // MARK: - Writing

    func insert(_ chars: [Character], at offset: Int) {
        guard !chars.isEmpty else { return }
        let addStart = add.count
        add.append(contentsOf: chars)

        // Fast path: typing contiguously extends the previous add-piece so the
        // piece list stays small during normal input.
        var pos = 0
        for i in pieces.indices {
            pos += pieces[i].length
            if pos == offset {
                if pieces[i].source == .add,
                   pieces[i].start + pieces[i].length == addStart {
                    pieces[i].length += chars.count
                    count += chars.count
                    return
                }
                break
            }
            if pos > offset { break }
        }

        insertPiece(Piece(source: .add, start: addStart, length: chars.count), at: offset)
        count += chars.count
    }

    private func insertPiece(_ np: Piece, at offset: Int) {
        if pieces.isEmpty {
            pieces.append(np)
            return
        }
        var pos = 0
        var i = 0
        while i < pieces.count {
            let p = pieces[i]
            if offset <= pos + p.length {
                let local = offset - pos
                if local == 0 {
                    pieces.insert(np, at: i)
                } else if local == p.length {
                    pieces.insert(np, at: i + 1)
                } else {
                    let left = Piece(source: p.source, start: p.start, length: local)
                    let right = Piece(source: p.source, start: p.start + local, length: p.length - local)
                    pieces[i] = left
                    pieces.insert(np, at: i + 1)
                    pieces.insert(right, at: i + 2)
                }
                return
            }
            pos += p.length
            i += 1
        }
        pieces.append(np)   // offset == count
    }

    func delete(_ range: Range<Int>) {
        guard !range.isEmpty else { return }
        var newPieces: [Piece] = []
        newPieces.reserveCapacity(pieces.count + 1)
        var pos = 0
        for p in pieces {
            let pStart = pos
            let pEnd = pos + p.length
            if pEnd <= range.lowerBound || pStart >= range.upperBound {
                newPieces.append(p)
                pos = pEnd
                continue
            }
            if pStart < range.lowerBound {
                newPieces.append(Piece(source: p.source, start: p.start,
                                       length: range.lowerBound - pStart))
            }
            if pEnd > range.upperBound {
                let off = range.upperBound - pStart
                newPieces.append(Piece(source: p.source, start: p.start + off,
                                       length: pEnd - range.upperBound))
            }
            pos = pEnd
        }
        pieces = newPieces
        count -= range.count
    }
}
