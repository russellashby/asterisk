# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

WordStarMac — a native macOS word processor inspired by **DOS WordStar 4.0**.
Goal: authentic text-mode experience with WordStar control-key commands and
**blindly fast text input**.

## Non-negotiable design constraints

These were settled with the user up front. Do not relitigate without asking:

- **Native, low-latency.** Swift + AppKit. No Electron, no web tech.
- **No Cocoa text stack.** Deliberately avoid `NSTextView`/TextKit — they add
  latency and take away control. Editing happens in a custom `NSView`.
- **Authentic text-mode look.** Fixed 80-column monospace character grid,
  letter-boxed into the window with a blue surround; status line + ruler.
- **Cell-grid renderer with diffing.** Render model → grid of `Cell`s; repaint
  only cells that changed. A keystroke / cursor blink must dirty ~one cell.
- **WordStar key bindings.** Modal control-key command system (the diamond,
  `^K` block, `^Q` quick, `^O` onscreen, `^P` print). We own `keyDown:` so all
  Ctrl combos are ours. Native Mac menus mirror commands and show the WS shortcut.
- **File compatibility scope: UX only.** Save/open plain text + our own native
  format. Not parsing/writing genuine WordStar `.ws` binary files.
- **Formatting scope: on-screen.** Dot commands, margins, bold/underline/italic
  markers, reformat. No print/PDF pipeline yet.

## Architecture (layers)

```
Input (keyDown) → Command FSM → Editor core → Document model
                                              → Layout → Cell-grid renderer
```

| File              | Responsibility                                       |
|-------------------|------------------------------------------------------|
| `main.swift`      | NSApplication entry point                            |
| `AppDelegate.swift` | Window + native menu setup                         |
| `EditorView.swift`| Input handling, geometry, render-to-grid, drawing    |
| `CellGrid.swift`  | `Cell` model + diffable grid buffer                  |
| `TextModel.swift` | **Phase 1 placeholder** line buffer → piece table next |
| `Theme.swift`     | Role-based colour palette (`Theme.classic`)          |

## Build / run

```sh
swift build              # compile
swift run                # build + launch
./bundle.sh              # produce double-clickable WordStar.app
```

Requires Command Line Tools (no full Xcode). Swift 6.x; the package pins
`swiftLanguageVersions: [.v5]` to avoid Swift 6 strict-concurrency friction on
AppKit main-thread code — keep it that way unless intentionally migrating.

## Roadmap (phased; build + verify each before the next)

1. **DONE** — Cell-grid renderer, 80-col letter-box, status/ruler, live typing,
   cursor diamond teaser. Phase 1 existed to de-risk latency; confirmed responsive.
2. Piece-table buffer, full cursor motion, word-wrap, insert/overtype.
3. WordStar command FSM, `^K`/`^Q` menus, blocks, find/replace, undo/redo.
4. On-screen formatting: dot commands, margins, bold/underline/italic, reformat,
   help levels (0–3).
5. Native-format file I/O, authentic `.BAK` backups, palettes, native menu mirroring.

## Conventions

- Keep the hot path (keystroke → mutate → diff → draw) allocation-free; no global
  relayout per keystroke. The monospace grid keeps layout O(1) — preserve that.
- `TextModel` is a known temporary; replacing it with a piece table is Phase 2's
  first task. Don't build heavily on its line-array API.
- Match the surrounding code style (clear MARK sections, role-based colours).
