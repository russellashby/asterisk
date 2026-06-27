# WordStarMac

A native macOS word processor inspired by DOS WordStar 4.0 — authentic text-mode
screen, WordStar control-key commands, built for blindly fast text input.

Swift + AppKit, custom `NSView` cell-grid renderer (no Electron, no TextKit).

## Phase 1 (current)

The latency-critical foundation:

- Custom layer-backed `NSView` that owns every keystroke.
- 80-column character grid, letter-boxed into a resizable window.
- Per-cell back/front-buffer **diffing** — only changed cells repaint.
- Authentic status line, ruler, block cursor with blink.
- Live typing; cursor diamond teaser (`^E`/`^X`/`^S`/`^D`) + arrow keys,
  Return, Backspace.

### Try it

```sh
swift run            # build + launch
```

Or build a double-clickable app:

```sh
./bundle.sh          # produces WordStar.app
open WordStar.app
```

Type to insert. Move with arrows or `^E`/`^X`/`^S`/`^D`. `⌘Q` quits.

## Roadmap

2. Piece-table buffer, full cursor motion, word-wrap, insert/overtype.
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
