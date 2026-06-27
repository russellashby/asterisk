# WordStarMac

A native macOS word processor inspired by DOS WordStar 4.0 — authentic text-mode
screen, WordStar control-key commands, built for blindly fast text input.

Swift + AppKit, custom `NSView` cell-grid renderer (no Electron, no TextKit).

## Status

**Phase 1 (done):** latency-critical foundation — custom layer-backed `NSView`
owning every keystroke, 80-column letter-boxed grid, per-cell diffing, status
line, ruler, blinking block cursor.

**Phase 2 (done):** piece-table edit buffer, incremental word-wrap layout, full
cursor motion, insert/overtype. AppKit-free core (`WSCore`) with unit tests.

**Phase 3 (done):** `^K`/`^Q` prefix command system, block ops (mark/copy/move/
delete with on-screen highlight), find & find/replace, multi-level undo/redo.
Native Edit menu mirrors the commands.

**Phase 4 (done):** inline bold/underline/italic (`^P`, rendered with real font
traits + highlighted markers), dot-command lines (dimmed), `^B` reform, help
levels 0–3 (`^J`), and amber/green/classic phosphor themes.

### Try it

```sh
swift run WordStarMac    # build + launch
swift run WSCoreTests    # run the core unit tests
```

Or build a double-clickable app:

```sh
./bundle.sh              # produces WordStar.app
open WordStar.app
```

### Keys (so far)

| Action | Keys |
|--------|------|
| Cursor | arrows · `^E`/`^X`/`^S`/`^D` (diamond) |
| Word left / right | `^A` / `^F` |
| Page up / down | `^R` / `^C` · PgUp/PgDn |
| Line start / end | Home / End |
| Delete char under cursor / word / line | `^G` / `^T` / `^Y` |
| Insert / overtype toggle | `^V` |
| Undo · find next | `^U` · `^L` |
| **Block** (`^K`) begin/end · copy · move · delete · hide | `^KB`/`^KK` · `^KC` · `^KV` · `^KY` · `^KH` |
| **Quick** (`^Q`) line start/end · doc top/bottom | `^QS`/`^QD` · `^QR`/`^QC` |
| **Quick** find · replace · to block · del-to-eol | `^QF` · `^QA` · `^QB`/`^QK` · `^QY` |
| **Print** (`^P`) bold · underline · italic | `^PB` · `^PS` · `^PY` |
| Reform paragraph · cycle help level | `^B` · `^J` |
| Native menu: Undo/Redo/Find/Replace | `⌘Z` `⌘⇧Z` `⌘F` `⌘G` `⌘R` |
| Quit | `⌘Q` |

## Roadmap

4b. Dynamic dot-command margins (`.lm`/`.rm`) and pagination (`.pa`/`.pl`).
5. Native-format file I/O, `.BAK` backups, palette switching, native menu mirroring.

## Layout

| File             | Responsibility                                  |
|------------------|-------------------------------------------------|
| `main.swift`     | NSApplication entry point                        |
| `AppDelegate.swift` | Window + menu setup                          |
| `EditorView.swift`  | Input, geometry, render-to-grid, drawing     |
| `CellGrid.swift`    | Cell model + grid buffer (diffable)          |
| `TextModel.swift`   | Phase 1 line buffer (piece table comes next) |
| `Theme.swift`       | Role-based colour palette                     |
