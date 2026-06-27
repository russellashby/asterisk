import Foundation

/// What a cell represents, which drives its colours at draw time.
enum CellRole: UInt8 {
    case text
    case status
    case ruler
    case blank
}

/// A single character cell. Equatable so the renderer can diff back/front
/// buffers and repaint only what actually changed.
struct Cell: Equatable {
    var ch: Character = " "
    var role: CellRole = .blank
    var bold = false
    var underline = false
    var inverse = false
}

/// A 2D grid of character cells — the "screen" in classic text-mode terms.
/// Pure data: geometry and drawing live in the view.
final class CellGrid {
    private(set) var cols: Int
    private(set) var rows: Int
    private(set) var cells: [Cell]

    init(cols: Int, rows: Int) {
        self.cols = max(1, cols)
        self.rows = max(1, rows)
        self.cells = Array(repeating: Cell(), count: self.cols * self.rows)
    }

    @inline(__always)
    func index(_ r: Int, _ c: Int) -> Int { r * cols + c }

    func cell(_ r: Int, _ c: Int) -> Cell {
        cells[index(r, c)]
    }

    /// Set a cell, returning true if its contents actually changed (so the
    /// caller can invalidate only what needs repainting).
    @discardableResult
    func set(_ r: Int, _ c: Int, _ cell: Cell) -> Bool {
        let i = index(r, c)
        guard cells[i] != cell else { return false }
        cells[i] = cell
        return true
    }

    /// Re-allocate to a new size (blanked). The view re-renders afterwards.
    func resize(cols newCols: Int, rows newRows: Int) {
        cols = max(1, newCols)
        rows = max(1, newRows)
        cells = Array(repeating: Cell(), count: cols * rows)
    }

    func clear() {
        for i in cells.indices { cells[i] = Cell() }
    }
}
