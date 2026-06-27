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

Two SwiftPM targets: **`WSCore`** (AppKit-free, unit-tested editor core) and
**`WordStarMac`** (the AppKit executable, depends on WSCore). A third executable
target `WSCoreTests` is an XCTest-free test runner (CLT has no XCTest).

| File                              | Responsibility                              |
|-----------------------------------|---------------------------------------------|
| `Sources/WSCore/PieceTable.swift` | Piece-table edit buffer (insert/delete/slice/snapshot) |
| `Sources/WSCore/Document.swift`   | Cursor, editing, word-wrap layout, blocks, find/replace, undo |
| `Sources/WSCore/Commands.swift`   | `EditorCommand` + ^K/^Q key→command resolution |
| `Sources/WSCore/Formatting.swift` | Inline format attrs + control-byte mapping |
| `Sources/WordStarMac/main.swift`  | NSApplication entry point                    |
| `Sources/WordStarMac/AppDelegate.swift` | Window + native menu setup            |
| `Sources/WordStarMac/EditorView.swift`  | Input, geometry, render-to-grid, drawing |
| `Sources/WordStarMac/CellGrid.swift`    | `Cell` model + diffable grid buffer   |
| `Sources/WordStarMac/Theme.swift`       | Role-based colour palette (`Theme.classic`) |
| `Tests/WSCoreTests/*`             | Standalone test runner for WSCore           |

## Build / run

```sh
swift build              # compile
swift run WordStarMac    # build + launch the app
swift run WSCoreTests    # run the core unit tests (exits non-zero on failure)
./bundle.sh              # produce double-clickable WordStar.app
```

Requires Command Line Tools (no full Xcode). Swift 6.x; the package pins
`swiftLanguageVersions: [.v5]` to avoid Swift 6 strict-concurrency friction on
AppKit main-thread code — keep it that way unless intentionally migrating.

**Testing note:** XCTest is unavailable under CLT-only, so tests are a plain
executable (`Tests/WSCoreTests`) using a tiny assert harness. WSCore is built
with `-enable-testing` so the runner can `@testable import` internals.

## Roadmap (phased; build + verify each before the next)

1. **DONE** — Cell-grid renderer, 80-col letter-box, status/ruler, live typing,
   cursor diamond teaser. Phase 1 existed to de-risk latency; confirmed responsive.
2. **DONE** — Piece-table buffer, incremental word-wrap layout, full cursor
   motion (diamond, word, line, page, doc), insert/overtype. Unit tested.
3. **DONE** — Command FSM (`^K`/`^Q` prefixes), block ops (mark/copy/move/
   delete/hide with highlight), find & find/replace (prompt input), undo/redo
   (snapshot-based, typing coalesced). Native Edit menu mirrors commands. Tested.
4. **DONE** — Inline formatting (`^P` bold/underline/italic, rendered with real
   font traits + highlighted markers), dot-command lines (recognised + dimmed),
   `^B` reform, help levels 0–3 (`^J`). Amber/green/classic phosphor themes.
   **Deferred to 4b:** dynamic `.lm`/`.rm` margin effects and `.pa`/`.pl`
   pagination (dot lines display but don't yet reflow/paginate).
5. Native-format file I/O, authentic `.BAK` backups, palette switching, native menu mirroring.

## Conventions

- Keep the hot path (keystroke → mutate → diff → draw) allocation-free; no global
  relayout per keystroke. Layout is incremental (per-paragraph) — preserve that;
  `Document.relayout` must stay equivalent to `forceFullRelayout` (fuzz-tested).
- The view derives everything from `Document` (cursor offset → line/col via the
  layout cache). Don't duplicate text state in the view.
- Match the surrounding code style (clear MARK sections, role-based colours).
