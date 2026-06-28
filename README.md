# Asterisk

**Asterisk** is a native macOS word processor inspired by DOS WordStar 4.0 —
authentic text-mode screen, WordStar control-key commands, built for blindly fast
text input. (Repository name: `WordStarMac`; the shipped app is **Asterisk**.)

Swift + AppKit, custom `NSView` cell-grid renderer (no Electron, no TextKit).

> **Name & trademarks.** Asterisk is an independent, clean-room tribute. It is
> not affiliated with, endorsed by, or derived from the source code of any owner
> of the "WordStar" trademark; that name is used here only to describe the
> historical software this project pays homage to.

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

**Phase 4b (done):** dot commands now *take effect* — `.lm`/`.rm` reflow and
indent following text (region-based, multiple regions supported), and
`.pa`/`.pl`/`.mt`/`.mb` drive page breaks shown as on-screen `Page N` divider
rules. Dotless documents keep the fast incremental layout (no pagination).

**Justification (done):** the `^O` onscreen menu with `^OJ` toggles full
justification (flush left + right), on by default like WordStar 4. Render-time
only (padding isn't saved); the final line of a paragraph stays ragged. Tab
(`^I`) indents to 5-column tab stops.

**Phase 5 (done):** file I/O — New/Open/Save/Save As (File menu + `^KS`/`^KR`),
lossless native format (text + control bytes + dot lines), `.BAK` backups,
dirty-state title and unsaved-changes prompt on close.

**CRT effects:** subtle scanlines + phosphor glow, **off by default**, both
toggleable from the **View** menu (no screen curvature). Pair nicely with the
amber theme.

**Clipboard:** `⌘C`/`⌘X` copy/cut the marked block to the system pasteboard,
`⌘V` pastes at the cursor (line-endings normalized, format bytes preserved).

## Install

Requires macOS 12+ and the Xcode Command Line Tools (`xcode-select --install`) —
no full Xcode needed. Swift 5.x toolchain.

### Run from source

```sh
git clone https://github.com/russellashby/asterisk.git
cd asterisk
swift run WordStarMac    # build + launch  (SwiftPM target name)
swift run WSCoreTests    # run the core unit tests
```

### Build a double-clickable app

```sh
./bundle.sh              # produces Asterisk.app
open Asterisk.app
```

> **First launch (Gatekeeper).** Release builds are **not code-signed**, so macOS
> will say *"Asterisk can't be opened because Apple cannot check it for malicious
> software."* This is expected for an unsigned open-source app. Either:
> - **right-click the app → Open**, then confirm **Open** in the dialog (only
>   needed once), or
> - clear the quarantine flag: `xattr -dr com.apple.quarantine Asterisk.app`.
>
> If you'd rather avoid this entirely, just run from source with `swift run`.

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
| **Onscreen** (`^O`) justify on/off | `^OJ` |
| **Dot commands** margins · page breaks | `.lm`/`.rm` · `.pa`/`.pl`/`.mt`/`.mb` |
| Reform paragraph · cycle help level | `^B` · `^J` |
| **File** (`^K`) save · read/open | `^KS` · `^KR` |
| Native menu: New/Open/Save/Save As | `⌘N` `⌘O` `⌘S` `⌘⇧S` |
| Native menu: Undo/Redo · Cut/Copy/Paste | `⌘Z` `⌘⇧Z` · `⌘X` `⌘C` `⌘V` |
| Native menu: Find/Find-next/Replace | `⌘F` `⌘G` `⌘R` |
| Quit | `⌘Q` |

## Roadmap / backlog

- CP437 bitmap font (DOS glyphs). _(CRT glow/scanlines done — View menu.)_
- Palette switching UI + fuller native menu mirroring.
- Remaining commands: `^QE`/`^QX`, more `^O` onscreen options (`^OC` center,
  `^OS` line spacing), `^P` print/PDF pipeline.

## Layout

| File             | Responsibility                                  |
|------------------|-------------------------------------------------|
| `main.swift`     | NSApplication entry point                        |
| `AppDelegate.swift` | Window + menu setup                          |
| `EditorView.swift`  | Input, geometry, render-to-grid, drawing     |
| `CellGrid.swift`    | Cell model + grid buffer (diffable)          |
| `TextModel.swift`   | Phase 1 line buffer (piece table comes next) |
| `Theme.swift`       | Role-based colour palette                     |
