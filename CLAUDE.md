# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

A native macOS word processor inspired by **DOS WordStar 4.0**. Goal: authentic
text-mode experience with WordStar control-key commands and **blindly fast text
input**.

**Naming (important — three different names):** the shipped app is **Asterisk**;
the public GitHub repo is **`russellashby/asterisk`** (public, MIT); but the local
folder and the SwiftPM executable target are still **`WordStarMac`** (renaming the
target was deliberately skipped). So you build/run with `swift run WordStarMac`
even though the app users see is Asterisk. Only user-visible strings (window
title, About/Quit menus, `bundle.sh`) say "Asterisk".

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
- **File compatibility scope: UX only.** Save/open **plain text (`.txt`)** — our
  on-disk format is raw text with embedded control bytes + dot lines. Not
  parsing/writing genuine WordStar `.ws` binary files; `.WS` is no longer used as
  a default extension (the saved bytes were never real WordStar files).
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
| `Sources/WSCore/DotCommands.swift` | Dot-command parsing (`.lm`/`.rm`/`.pa`/`.pl`/`.mt`/`.mb`) + layout defaults |
| `Sources/WordStarMac/main.swift`  | NSApplication entry point                    |
| `Sources/WordStarMac/AppDelegate.swift` | Window + native menu setup            |
| `Sources/WordStarMac/EditorView.swift`  | Input, geometry, render-to-grid, drawing |
| `Sources/WordStarMac/CellGrid.swift`    | `Cell` model + diffable grid buffer   |
| `Sources/WordStarMac/Theme.swift`       | Role-based colour palette (`Theme.classic`) |
| `Tests/WSCoreTests/*`             | Standalone test runner for WSCore           |

## Build / run

```sh
swift build              # compile
swift run WordStarMac    # build + launch the app (target name is WordStarMac)
swift run WSCoreTests    # run the core unit tests (exits non-zero on failure)
./bundle.sh              # produce + ad-hoc-sign double-clickable Asterisk.app
```

Requires Command Line Tools (no full Xcode). Swift 6.x; the package pins
`swiftLanguageVersions: [.v5]` to avoid Swift 6 strict-concurrency friction on
AppKit main-thread code — keep it that way unless intentionally migrating.

**Testing note:** XCTest is unavailable under CLT-only, so tests are a plain
executable (`Tests/WSCoreTests`) using a tiny assert harness. WSCore is built
with `-enable-testing` so the runner can `@testable import` internals.

## Distribution / releases

Open-sourced (MIT) at `github.com/russellashby/asterisk`. GitHub Actions CI
(`.github/workflows/ci.yml`) runs build + `WSCoreTests` + `./bundle.sh` on macOS.

To cut a release (latest is **v0.2**):
1. Bump `CFBundleVersion` / `CFBundleShortVersionString` in `bundle.sh`.
2. `./bundle.sh` → builds + **ad-hoc code-signs** `Asterisk.app`.
3. `ditto -c -k --keepParent Asterisk.app Asterisk-vX.Y-macos.zip` (use `ditto`,
   not `zip`, so the code signature survives the round-trip).
4. `gh release create vX.Y Asterisk-vX.Y-macos.zip --title … --notes-file …`.

The build is **unsigned/unnotarized** (no Apple Developer ID). `bundle.sh` ad-hoc
signs the *bundle* (`codesign --force --deep --sign -`) — this is required: without
it the Swift linker signs only the inner arm64 binary, leaving the bundle without
`_CodeSignature/CodeResources`, and a quarantined download is reported as
**"damaged"** on Apple Silicon. Ad-hoc signing downgrades that to the normal
"unidentified developer" prompt (right-click → Open). Release zips are gitignored.

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

4b. **DONE** — Dot commands take effect: `.lm`/`.rm` reflow & indent following
   text (region-based, multi-region); `.pa`/`.pl`/`.mt`/`.mb` drive page breaks
   shown as on-screen `Page N` divider rules. Gated on `dotCount > 0` so the
   common dotless document keeps the fast incremental layout (no pagination).

4c. **DONE** — `^O` onscreen menu with `^OJ` full justification (on by default,
   WS4-style). Render-time only: each `VisualLine` stores its wrap `width` and
   `Document.justifiedColumns(_:)` maps char→column for both renderer and cursor;
   toggling needs no relayout. Tab (`^I`) indents to 5-column stops.
5. **DONE** — File I/O: New/Open/Save/Save As (File menu + `^KS`/`^KR`), saves as
   plain text (`.txt`, save panel constrained to `.plainText`) — raw text with
   control bytes + dot lines (lossless round-trip), `.BAK` backups, revision-based
   dirty tracking, window title + close prompt.
   **Remaining backlog:** CP437 font, palette switching UI, more ^O options
   (center, line spacing), ^P print/PDF pipeline, Apple Developer ID
   signing+notarization (to drop the Gatekeeper prompt).

**Also done (unnumbered, since phase 5):** system clipboard (`⌘C`/`⌘X`/`⌘V`),
CRT scanlines + glow (View menu, **off by default**), Tab/`^I` indent to 5-col
stops, `^OJ` justification (4c), **View ▸ Zoom** (`⌘+`/`⌘-`/`⌘0`) — scales the
font and resizes the window terminal-style to keep 80 cols (skipped in full
screen / `isZoomed`, where the grid just re-centres).

## Active plans

- None open. Phase 4b (dot-command margins + pagination) is **done** — see
  [`docs/PHASE_4B_PLAN.md`](docs/PHASE_4B_PLAN.md) for the design rationale.
- User-facing key reference + behaviour lives in [`docs/MANUAL.md`](docs/MANUAL.md);
  keep it in sync when commands change.

## Conventions

- Keep the hot path (keystroke → mutate → diff → draw) allocation-free; no global
  relayout per keystroke. Layout is incremental (per-paragraph) — preserve that;
  `Document.relayout` must stay equivalent to `forceFullRelayout` (fuzz-tested).
- **Layout fuzz invariant (bites easily):** the incremental path (`relayout` →
  `wrapParagraphs`/`appendLogicalLine`) must produce byte-identical `lines` to
  `forceFullRelayout` for dotless docs (asserted by the fuzz tests). Any new
  per-`VisualLine` field must be set **identically in both paths**, including the
  dot, empty, and **trailing-empty** line cases — a mismatch there (e.g. `width`
  defaulting to 0 in one path) silently breaks the invariant. Docs with dot
  commands always go through `forceFullRelayout` (gated on `dotCount > 0`).
- **On-screen decorations must live in the `Cell` model** so the diff renderer
  clears them when they move. The page-break rule + `Page N` label are driven by
  `Cell.pageBreakTop` / grid cells; an earlier version drew them as a `draw()`
  overlay and left stale artifacts on partial repaints.
- **Justification is render-time only** (`Document.justifiedColumns`, from
  `VisualLine.width`); it never mutates the buffer, so saves stay lossless and
  toggling `^OJ` needs no relayout. Renderer *and* cursor must use the same
  mapping or the caret drifts on justified lines.
- The view derives everything from `Document` (cursor offset → line/col via the
  layout cache). Don't duplicate text state in the view.
- Match the surrounding code style (clear MARK sections, role-based colours).
