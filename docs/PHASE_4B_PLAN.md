# Phase 4b plan — dynamic dot-command margins + pagination

Status: **DONE** (task #2). Dot-command lines were already *recognised and
displayed dimmed* (Phase 4); this phase makes them *take effect*. Implemented in
`DotCommands.swift` (parsing), `Document.swift` (margin/pagination-aware
`forceFullRelayout`, `dotCount` gating, `pageBreakBeforeLine`) and
`EditorView.swift` (leftIndent rendering + `Page N` divider rules), with
`Tests/WSCoreTests/MarginTests.swift` covering margins and pagination.

Read this top-to-bottom before coding. It's written to be implementable cold.

## Goal

1. **Margins**: `.lm n` (left margin) and `.rm n` (right margin) change the wrap
   region for all following text, until changed again (region-based).
2. **Pagination**: `.pa` forces a page break; `.pl n` (page length), `.mt n`
   (margin top), `.mb n` (margin bottom) drive *automatic* page breaks. Page
   boundaries are shown on screen.

WordStar columns are **1-based**. Defaults: lm=1, rm=65 (current `wrapWidth`),
pl=66, mt=3, mb=3 → ~60 text lines per page.

## Current architecture (recap — read the code, this is orientation)

- `Sources/WSCore/Document.swift`
  - `pt: PieceTable` (the buffer), `lines: [VisualLine]` (layout cache), cursor
    as a single linear `offset`, `wrapWidth`.
  - `VisualLine { start, end, entry: TextAttrs, isDot: Bool }` — content is the
    half-open range `[start,end)`; gap to next line start is 0 (soft wrap) or 1
    (the `\n`).
  - `forceFullRelayout()` → `wrapParagraphs(0, count)`.
  - `wrapParagraphs(a,b)` splits the span into logical lines on `\n`, calls
    `appendLogicalLine` which emits a dot line whole (isDot=true) or greedy-wraps
    at `wrapWidth`, recording per-line `entry` format attrs.
  - `relayout(editStart:delta:)` is the **incremental** path: re-wraps only the
    touched paragraph and shifts following line offsets by `delta`. A fuzz test
    asserts incremental == full layout.
- `Sources/WordStarMac/EditorView.swift`
  - `renderText()` draws each visible visual line starting at **grid column 0**;
    dot lines dimmed; format attrs/markers applied; block highlight by offset.
  - Cursor screen position: `gridCursorCol = doc.cursorColumn`.

## Key design decision: gate incremental layout on presence of dot commands

Region margins/pagination depend on a **document-prefix scan** (active margins at
a paragraph depend on all preceding dot commands). The per-paragraph incremental
path cannot know that context. Solution:

- Track `dotCount` (number of dot lines), maintained incrementally.
- **If `dotCount > 0`, always `forceFullRelayout()`** (which is margin/pagination
  aware). Otherwise keep the existing fast incremental path (margins default,
  `leftIndent` 0, no page breaks).

This keeps the common case (no dot commands) fast, and only pays full-relayout
cost when the document actually uses dot commands (rare; docs are small). The
incremental==full fuzz test still holds because both paths produce identical
`lines` when dots are present (both go through `forceFullRelayout`).

### Maintaining `dotCount`
- `forceFullRelayout()`: set `dotCount = lines.reduce(0){ $0 + ($1.isDot ?1:0) }`.
- `relayout(...)` (incremental): after computing the spliced `mid`, adjust
  `dotCount += (dots in mid) − (dots in replaced old range [k,m))`. Then **if the
  resulting `dotCount > 0`, discard the splice and call `forceFullRelayout()`**
  (correctness over micro-optimisation; only happens with dot commands present).

## Implement in two stages (test each before the next)

### Stage 1 — margins (`.lm` / `.rm`)

1. **VisualLine**: add `var leftIndent: Int = 0`. (Equatable stays synthesised.)
2. **Dot parsing** (new file `Sources/WSCore/DotCommands.swift`):
   ```swift
   struct DotDirective { var lm:Int?; var rm:Int?; var pa:Bool; var pl:Int?; var mt:Int?; var mb:Int? }
   func parseDot(_ chars: ArraySlice<Character>) -> DotDirective?  // nil if not a dot line
   ```
   Recognise `.lm`,`.rm`,`.pa`,`.pl`,`.mt`,`.mb` (2-letter, case-insensitive,
   optional space, integer arg). Ignore others (still displayed). Numbers parse
   from the remainder; clamp to sane ranges.
3. **forceFullRelayout()** → make it margin-aware. Stop reusing
   `wrapParagraphs(0,count)`; instead scan the whole document in order tracking
   `lm`, `rm` state:
   - default `lm=1, rm=wrapWidth`.
   - For each logical line: if dot, emit dot VisualLine (leftIndent 0, isDot
     true) and apply directive to `lm`/`rm` for *subsequent* lines.
   - Else wrap at `width = max(1, rm - (lm-1))` and set `leftIndent = lm-1` on
     each produced visual line (reuse the greedy-wrap + entry-attr logic from
     `appendLogicalLine`, but parameterised by `width` and `leftIndent`).
   - Keep `wrapParagraphs`/`appendLogicalLine` for the incremental no-dot path
     (leftIndent 0, width = wrapWidth). Refactor the greedy wrap into a shared
     helper taking `(width, leftIndent)` so both paths share it.
   - Guard: `rm ≤ textColumns (80)`, `1 ≤ lm < rm`.
4. **Accessor**: `public func lineLeftIndent(_ i:Int) -> Int { lines[i].leftIndent }`.
5. **relayout() gating**: implement the `dotCount > 0 → forceFullRelayout()` rule
   above.
6. **EditorView.renderText()**: render each line's content starting at grid
   column `doc.lineLeftIndent(lineIndex)` (blank the indent cells). Block
   highlight must map document offset → screen column `leftIndent + (off-start)`.
7. **Cursor**: `gridCursorCol = doc.lineLeftIndent(cursorLine) + doc.cursorColumn`
   (clamp to grid width).
8. *(Optional polish)* Ruler row: move the `L`/`R` markers to reflect active
   lm/rm of the cursor's region.
9. **Tests** (`Tests/WSCoreTests/MarginTests.swift`, add `runMarginTests()` to
   `main.swift`):
   - `.lm 5\nhello` → `lineLeftIndent` of the text line == 4.
   - `.rm 10` makes following long text wrap at width 10.
   - Two regions: `.rm 10` … `.rm 70` … → second region wraps wider.
   - Editing within a margin region keeps offsets/cursor correct.

### Stage 2 — pagination (`.pa` / `.pl` / `.mt` / `.mb`)

**Represent page breaks as display-only markers — NOT entries in `lines`** (so
cursor/offset mapping is untouched).

1. **Document**: add `private(set) public var pageBreakBeforeLine: [Int] = []`
   (sorted visual-line indices before which a page boundary falls).
2. In `forceFullRelayout()`'s scan, also track `linesThisPage` and
   `pendingBreak`:
   - page capacity `cap = max(1, pl - mt - mb)`.
   - `.pa` → `pendingBreak = true`.
   - Before emitting each **text** visual line (dot lines don't count toward the
     page): if `pendingBreak` or `linesThisPage >= cap`, append the about-to-be
     index to `pageBreakBeforeLine`, reset `linesThisPage = 0`, clear
     `pendingBreak`. Then emit and `linesThisPage += 1`.
3. **Rendering — recommended simple first cut (no extra grid rows):** in
   `EditorView.draw`, for any visible line whose index is in
   `pageBreakBeforeLine`, draw a thin horizontal divider rule along the **top
   edge** of that line's cell row (across the 80-col grid), optionally with a
   right-aligned `Page N` label. This needs **no** cursor-row/scroll math because
   no screen row is consumed.
   - If a more authentic full marker row is wanted later, switch to interleaving
     a non-selectable marker row and adjust `gridCursorRow`/scroll by
     `(# breaks with index ≤ line) ` — deferred; document it but don't start here.
4. **Tests** (`PaginationTests` or extend MarginTests):
   - `.pa` between two paragraphs → `pageBreakBeforeLine` contains the next
     text line's index.
   - small `.pl` (e.g. `.pl 8` with mt=mb=0 via `.mt 0`/`.mb 0`) → a break every
     `cap` text lines.
   - dot lines don't increment the page counter.

## Edge cases / gotchas

- Keep lines within 80 display columns: clamp `rm ≤ 80`, `lm ≥ 1`, `lm < rm`;
  if a directive is silly, ignore it (still display the dot line).
- Dot lines: `leftIndent = 0`, never wrapped, **not** counted as page text lines.
- The incremental==full fuzz test (`FormattingTests.runFormattingTests`) must
  still pass — its alphabet already includes `.`; verify `leftIndent` matches in
  both paths (it will, because dots force full relayout). Consider asserting
  `pageBreakBeforeLine` equality after a `forceFullRelayout` too.
- `undo`/`redo` call `apply` → `forceFullRelayout`, so margins/pagination recompute
  correctly for free.
- Performance: full relayout slices the whole doc each edit when dots are present.
  Fine for normal docs. If it ever matters, cache a "margin map" (offset→lm/rm)
  and make incremental margin-aware — explicitly out of scope here.

## Files to touch
- `Sources/WSCore/Document.swift` (VisualLine field, forceFullRelayout rewrite,
  relayout gating, dotCount, pageBreakBeforeLine, accessors).
- `Sources/WSCore/DotCommands.swift` (new — parsing).
- `Sources/WordStarMac/EditorView.swift` (renderText leftIndent, cursor col,
  page-break divider in draw, optional ruler).
- `Tests/WSCoreTests/MarginTests.swift` (new) + register in `main.swift`.

## Definition of done
- `.lm`/`.rm` visibly indent/re-wrap following text; multiple regions work.
- `.pa` and automatic `.pl` page breaks show on screen.
- `swift run WSCoreTests` passes (incl. existing fuzz + new margin/pagination).
- `swift build -c release` and app launches; manual check in the editor.
- Update `CLAUDE.md` roadmap (mark 4b done) + `README.md`; mark task #2 complete.
