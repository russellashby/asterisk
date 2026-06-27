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
| Delete char under cursor | `^G` |
| Insert / overtype toggle | `^V` |
| Quit | `⌘Q` |

## Roadmap

3. WordStar command FSM, `^K`/`^Q` menus, blocks, find/replace, undo/redo.
4. On-screen formatting: dot commands, margins, bold/underline/italic, reformat, help levels.
5. Native-format file I/O, `.BAK` backups, palettes, native menu mirroring.

## Layout

| File             | Responsibility                                  |
|------------------|-------------------------------------------------|
| `main.swift`     | NSApplication entry point                        |
| `AppDelegate.swift` | Window + menu setup                          |
| `EditorView.swift`  | Input, geometry, render-to-grid, drawing     |
| `CellGrid.swift`    | Cell model + grid buffer (diffable)          |
| `TextModel.swift`   | Phase 1 line buffer (piece table comes next) |
| `Theme.swift`       | Role-based colour palette                     |
