# WordStarMac — Instruction Manual

A native macOS word processor modelled on **DOS WordStar 4.0**: an 80‑column
text‑mode grid, modal control‑key commands, and dot commands for margins and
pagination. This manual describes **what the program actually does today** (it is
written from the source, not from the original WordStar manual), so where our
behaviour differs from classic WordStar that is called out.

> Notation: `^K` means hold **Ctrl** and press **K**. `⌘` is the Mac Command key
> (the native menu bar). Commands are **case‑insensitive** — `^KB` and `^Kb` are
> the same.

---

## 1. Core concepts

- **Everything is keyboard‑driven and modal.** Some commands are a single
  control key (e.g. `^Y` deletes a line). Others are a **two‑key prefix**: you
  press a prefix (`^K`, `^Q`, or `^P`), the info line shows a menu of choices,
  and then you press one more letter. Press **Esc** to back out of a prefix.
- **The cursor diamond.** WordStar moves the cursor with the “diamond” of keys
  around the home row: `^E` up, `^X` down, `^S` left, `^D` right. The arrow keys
  do the same thing.
- **One linear cursor.** Internally the document is a stream of characters; line
  and column are derived from word‑wrap layout. Word wrap happens automatically —
  you don’t press Return at the end of every line, only to end a paragraph.
- **The status line** (top row) shows: file name · `L{line} C{column}` · INSERT
  or OVERTYPE · `BLOCK` if a block is marked · current HELP level.
  - `C{column}` is the **column within the line’s text**, counted from 1. With a
    left margin (`.lm`) in force the text is indented on screen but `C` still
    counts from the first character, so the on‑screen caret can be further right
    than the `C` number suggests.

---

## 2. Files

| Action | WordStar keys | Mac menu |
|--------|---------------|----------|
| New document | — | **File ▸ New** (`⌘N`) |
| Open / read a file | `^KR` | **File ▸ Open** (`⌘O`) |
| Save | `^KS` (also `^KD`, `^KX`) | **File ▸ Save** (`⌘S`) |
| Save As | — | **File ▸ Save As** (`⌘⇧S`) |

- Saving writes **plain text with our control bytes and dot lines intact**, so a
  document round‑trips losslessly. A `.BAK` backup of the previous version is
  written next to the file on each save.
- The window title shows a `•` and a bullet when there are unsaved changes;
  closing with unsaved changes prompts you to Save / Don’t Save / Cancel.
- `^KD` and `^KX` (“done”/“exit” in WordStar) currently just **save** — they do
  not close the window or quit. Use `⌘W` / `⌘Q` for that.

---

## 3. Moving the cursor

| Move | Diamond / Ctrl | Also |
|------|----------------|------|
| Up one line | `^E` | ↑ |
| Down one line | `^X` | ↓ |
| Left one char | `^S` | ← |
| Right one char | `^D` | → |
| Word left | `^A` | — |
| Word right | `^F` | — |
| Page up | `^R` | Page Up |
| Page down | `^C` | Page Down |
| Start of line | `^QS` | Home |
| End of line | `^QD` | End |
| Top of document | `^QR` | — |
| Bottom of document | `^QC` | — |

“Page” means one screen of text rows.

---

## 4. Editing and deleting

| Action | Keys |
|--------|------|
| Insert a new line / split paragraph | Return |
| **Indent** to the next tab stop | Tab (or `^I`) |
| Delete char **before** cursor (backspace) | `^H` or Delete |
| Delete char **under** cursor (forward) | `^G` or Fn‑Delete |
| Delete the **word** to the right | `^T` |
| Delete the **whole current line** | `^Y` |
| Delete from cursor to **end of line** | `^QY` |
| Reform (re‑wrap) the paragraph | `^B` |

Because wrapping is automatic, `^B` (reform) mostly just normalises the layout;
text is always reflowed to the current margins as you type.

**Tab / indent.** Tab (or `^I`) indents to the next tab stop — every **5
columns**, the same stops marked with `!` on the ruler. Tabs are stored as plain
spaces, so they word-wrap, save and round-trip like ordinary text; remove an
indent with Backspace.

### Insert vs. Overtype

`^V` toggles between **INSERT** (characters push existing text right) and
**OVERTYPE** (characters replace what’s under the cursor). The mode is shown on
the status line. Overtype will not type over a line break.

---

## 5. Blocks — the `^K` menu

A *block* is a marked span of text. Mark its two ends, then copy/move/delete it.

| `^K` then… | Action |
|------------|--------|
| `B` | Mark **block begin** at the cursor |
| `K` | Mark **block end** at the cursor |
| `C` | **Copy** the block to the cursor |
| `V` | **Move** the block to the cursor |
| `Y` | **Delete** the block |
| `H` | **Hide/show** the block highlight (toggle) |
| `S` / `D` / `X` | **Save** the document |
| `R` | **Open/read** a file |

Marked text is shown highlighted (inverse). To **jump** to the marks use the
Quick menu: `^QB` → block begin, `^QK` → block end.

> The `^K` menu mixes block *and* file commands, exactly as classic WordStar did.

---

## 6. The Quick menu — `^Q`

| `^Q` then… | Action |
|------------|--------|
| `S` | Start of line |
| `D` | End of line |
| `R` | Top of document |
| `C` | Bottom of document |
| `B` | Jump to block begin |
| `K` | Jump to block end |
| `Y` | Delete to end of line |
| `F` | **Find** (prompts for text) |
| `A` | **Find & replace** (prompts for find, then replace) |

### Find & replace

- `^QF` (or `⌘F`): type the search text, press Return. Search is
  **case‑insensitive** and wraps around the end of the document.
- `^L` (or `⌘G`): repeat the last find.
- `^QA` (or `⌘R`): type the search text, Return, then the replacement, Return.
  Replaces **all** occurrences from the cursor to the end of the document and
  reports how many. (One undo step.)
- Press **Esc** to cancel a prompt.

---

## 7. Undo / redo

| Action | Keys |
|--------|------|
| Undo | `^U` or `⌘Z` |
| Redo | `⌘⇧Z` (no Ctrl key for redo) |

Typing is coalesced into a single undo step per run; structural edits (newlines,
deletes, block ops, replace‑all, paste) are their own steps.

---

## 8. Inline formatting — the `^P` menu

Inline styles are stored as **embedded control bytes** that toggle a style on and
then off again, WordStar‑style. The marker is shown as a highlighted letter; the
text between two markers is styled.

| `^P` then… | Inserts a toggle for | Marker |
|------------|----------------------|--------|
| `B` | **Bold** | `B` |
| `S` | **Underline** | `S` |
| `Y` | *Italic* | `Y` |

So to bold a word: `^PB`, type the word, `^PB` again. The two `B` markers show
inverse; the text between them renders bold using a real bold font. Styles carry
across soft‑wrapped lines and **reset at a hard line break** (Return).

---

## 9. Dot commands — margins & pagination

A **dot command** is a line whose **very first character is a period (`.`)**. It
controls layout but is not printed as body text. On screen dot lines are shown
**dimmed**. Recognised commands take effect on the text that **follows** them,
until changed again (they are *region‑based*).

Type them on their own line, e.g.:

```
.lm 10
.rm 60
This paragraph now wraps between columns 10 and 60…
```

### Supported commands

| Command | Meaning | Default |
|---------|---------|---------|
| `.lm n` | **Left margin** — text indents to column `n` (1‑based) | `1` |
| `.rm n` | **Right margin** — text wraps at column `n` | `65` |
| `.pa` | **Page break** — force a new page before the next line | — |
| `.pl n` | **Page length** — total lines per physical page | `66` |
| `.mt n` | **Margin top** — blank lines reserved at the top of a page | `3` |
| `.mb n` | **Margin bottom** — blank lines reserved at the bottom | `3` |

- Format: a `.`, the two‑letter command (case‑insensitive), an optional space,
  then an integer, e.g. `.LM 8`, `.rm12`, `.Pl 60`. `.pa` takes no number.
- **Columns are 1‑based.** `.lm 1` means no indent; `.lm 6` indents five spaces.

### How margins behave

The wrap region is the span between the left and right margins. Width =
`rm − (lm − 1)`. Change either margin and **all following paragraphs reflow** to
the new region; change it again to start a new region. Multiple regions in one
document are supported.

### How pagination behaves

The number of body lines that fit on a page is:

```
text lines per page = pl − mt − mb        (default 66 − 3 − 3 = 60)
```

When the body fills that many lines, or when a `.pa` is hit, a **page boundary**
is drawn: a thin divider rule across the page with a right‑aligned `Page N`
label, sitting above the first line of the new page. Dot‑command lines do **not**
count toward the page (only body text lines do).

To see short pages quickly, try:

```
.pl 8
.mt 0
.mb 0
line one
line two
…
```

That gives 8 body lines per page.

### Validation (silently ignored if invalid)

- `.rm` is clamped to a maximum of **80** (the grid width) and must be greater
  than the current left margin.
- `.lm` must be `≥ 1` and **less than** the current right margin.
- `.pl ≥ 1`, `.mt ≥ 0`, `.mb ≥ 0`.
- A command with a missing or out‑of‑range number is **ignored**, but the dot
  line is still shown (dimmed). Likewise an unrecognised `.xx` line is displayed
  and otherwise ignored.

---

## 10. Help levels

`^J` cycles the help level **3 → 2 → 1 → 0 → 3**. Higher levels show more of the
on‑screen menu at the top; level 0 hides it entirely for maximum text area. The
current level is shown on the status line.

---

## 11. Mac niceties (native menu bar)

These complement the WordStar keys; they are standard Mac shortcuts.

| Menu | Shortcut | Action |
|------|----------|--------|
| Edit ▸ Undo / Redo | `⌘Z` / `⌘⇧Z` | Undo / redo |
| Edit ▸ Cut / Copy / Paste | `⌘X` / `⌘C` / `⌘V` | **System clipboard** (Copy/Cut act on the marked block; Paste inserts at the cursor) |
| Edit ▸ Find / Find Next / Replace | `⌘F` / `⌘G` / `⌘R` | Same as `^QF` / `^L` / `^QA` |
| File ▸ New / Open / Save / Save As | `⌘N` / `⌘O` / `⌘S` / `⌘⇧S` | |
| View ▸ Scanlines / Glow | — | Toggle the CRT scan‑line and phosphor‑glow effects |

The pasteboard Copy/Cut use the **block** (mark it first with `^KB`/`^KK`); paste
normalises line endings and preserves embedded format bytes.

---

## 12. Full keyboard reference

**Single Ctrl keys**

```
^E up      ^X down    ^S left    ^D right     (cursor diamond)
^A word←   ^F word→   ^R pg-up   ^C pg-down
^G del→    ^H del←    ^T del-word ^Y del-line
^B reform  ^V ins/over ^U undo   ^L find-next  ^J help-level
^I tab/indent (or the Tab key)
^K block menu   ^Q quick menu   ^P print menu
```

**`^K` block / file** `B`/`K` mark · `C` copy · `V` move · `Y` delete · `H` hide
· `S`/`D`/`X` save · `R` open

**`^Q` quick** `S`/`D` line start/end · `R`/`C` doc top/bottom · `B`/`K` to block
· `Y` del‑to‑eol · `F` find · `A` replace

**`^P` print** `B` bold · `S` underline · `Y` italic

**Dot commands** `.lm` `.rm` margins · `.pa` `.pl` `.mt` `.mb` pagination

---

## 13. Things that look like bugs but are by design (today)

If something feels off, check here first:

1. **No page boundaries until you use a dot command.** Pagination is only
   computed when the document contains **at least one** dot command. A long
   document with *no* dot commands shows **no** `Page N` rules at all. Add any
   dot command (even `.lm 1`) and the default 60‑line pages appear. This keeps
   the common case fast.
2. **The ruler’s `L`/`R` markers don’t move.** The ruler row always shows `L` at
   column 1 and `R` at column 65, regardless of the active `.lm`/`.rm`. The text
   itself *does* reflow; only the ruler markers are not yet margin‑aware.
3. **A dot command must start in column 1.** A leading space (e.g. ` .lm 5`)
   makes it ordinary text, not a command.
4. **Invalid dot values are silently ignored** — the line stays visible (dimmed)
   but has no effect. E.g. `.rm 200` is clamped to 80; `.lm 90` (≥ rm) is ignored.
5. **`.rm` is capped at 80** because the screen is an 80‑column grid.
6. **The status‑line `C` column ignores the left margin.** With `.lm 6`, the
   first character of a line is `C1` even though the caret sits at screen
   column 6.
7. **`^KD` / `^KX` save but don’t exit.** They are aliases for save; use `⌘W` /
   `⌘Q` to close or quit.
8. **No Ctrl‑key redo.** Redo is `⌘⇧Z` only.

If you hit behaviour that *isn’t* in this list, it may be a genuine bug worth
reporting — note the exact keys/dot commands and what you expected.
