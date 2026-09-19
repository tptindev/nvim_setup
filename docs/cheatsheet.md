# Neovim Cheatsheet

Quick note for this config:

- `mapleader = <Space>`
- `maplocalleader = \`

## Core Options In This Config

These are not keymaps, but they strongly affect day-to-day editing behavior.

| Option / Behavior            | Value / Effect                                      |
| ---------------------------- | --------------------------------------------------- |
| Line numbers                 | Absolute in normal mode, relative outside insert    |
| Cursor guides                | `cursorline`, `cursorlineopt=screenline`; `cursorcolumn` off |
| Wrapping                     | Disabled (`wrap = false`)                           |
| Scroll offset                | `3` lines                                           |
| Search                       | `ignorecase`, `smartcase`, no persistent highlight  |
| Substitution preview         | `inccommand = split`                                |
| Folding                      | Treesitter `foldexpr` for C/C++/CMake/GLSL/Lua/Python, `indent` elsewhere; everything starts unfolded |
| Indentation                  | `autoindent`, `copyindent`, `breakindent`           |
| Tabs / indents               | `tabstop = 2`, `shiftwidth = 2`                     |
| Spell check                  | `en_us`, prose filetypes only (markdown, text, gitcommit, help) |
| Clipboard                    | Uses system clipboard (`unnamedplus`)               |
| Undo                         | Persistent undo enabled                             |
| Colors                       | 24-bit color enabled (`termguicolors`)              |
| Tabline                      | Always shown (`showtabline = 2`)                    |
| Command line                 | Hidden when idle (`cmdheight = 0`)                  |
| File formats                 | Writes Unix line endings by default                 |
| Sign column                  | Always visible, so diagnostics do not shift text    |
| Splits                       | `splitright`, `splitbelow`                          |
| Mouse                        | `mouse = a` (every mode), `mousemodel = popup_setpos`, `mousemoveevent` on |

## Statusline

The statusline uses `lualine.nvim` in a focused IDE layout:

- Left side: mode, Git branch, and diff summary
- Middle: current file path plus modified or readonly state
- Right side: diagnostics, attached LSP clients, filetype, progress, and line/column

Inactive windows keep a quieter statusline, and the dashboard disables the normal statusline entirely.

## Core Default Keymaps

These are common built-in Vim/Neovim motions and actions worth remembering.

### Normal Mode

| Key                     | Action                                       |
| ----------------------- | -------------------------------------------- |
| `h` `j` `k` `l`         | Move left/down/up/right                      |
| `w` / `b` / `e`         | Move by word                                 |
| `0` / `^` / `$`         | Start / first non-blank / end of line        |
| `gg` / `G`              | Top / bottom of file                         |
| `%`                     | Jump between matching pairs                  |
| `fx` / `tx`             | Find character `x` on current line           |
| `;` / `,`               | Repeat last `f`/`t` search forward/backward  |
| `i` / `a`               | Insert before / after cursor                 |
| `I` / `A`               | Insert at line start / line end              |
| `o` / `O`               | New line below / above and enter insert mode |
| `dd` / `yy`             | Delete line / yank line                      |
| `p` / `P`               | Paste after / before cursor                  |
| `"+y` / `"+p`           | Copy / paste with the system clipboard       |
| `u` / `<C-r>`           | Undo / redo                                  |
| `x` / `X`               | Delete char under / before cursor            |
| `.`                     | Repeat last change                           |
| `/pattern` / `?pattern` | Search forward / backward                    |
| `n` / `N`               | Next / previous search result                |
| `*` / `#`               | Search word under cursor forward / backward  |
| `v` / `V` / `<C-v>`     | Visual / linewise visual / block visual      |
| `ciw`                   | Change inner word                            |
| `di(`                   | Delete inside parentheses                    |
| `yi"`                   | Yank inside quotes                           |
| `:w` / `:q` / `:wq` / `:waq` | Save / quit / save and quit            |
| `:nohlsearch`           | Clear search highlight                       |

### Window And Tab Management

| Key                  | Action                                   |
| -------------------- | ---------------------------------------- |
| `<C-w>h` `j` `k` `l` | Move between windows                     |
| `<C-w>s` / `<C-w>v`  | Split horizontally / vertically          |
| `<C-w>c` / `<C-w>o`  | Close current window / keep only current |
| `:tabnew`            | Open a new tab                           |
| `gt` / `gT`          | Next / previous tab                      |

### Buffers

| Key              | Action                    |
| ---------------- | ------------------------- |
| `:bnext` / `:bprev` | Next / previous buffer |
| `:bdelete`       | Close current buffer      |

### Clipboard And Selection

| Key            | Action                               |
| -------------- | ------------------------------------ |
| `yy` / `y`     | Copy line / selected text            |
| `p` / `P`      | Paste after / before cursor          |
| `dd` / `d`     | Cut line / selected text             |
| `"+yy`         | Copy current line to system clipboard |
| `"+y`          | Copy selection to system clipboard   |
| `"+p` / `"+P`  | Paste from system clipboard          |

### Insert Mode

| Key     | Action                    |
| ------- | ------------------------- |
| `<Esc>` | Back to normal mode       |
| `<C-w>` | Delete previous word      |
| `<C-u>` | Delete to start of line   |
| `<C-h>` | Delete previous character |

## Custom Keymaps In This Config

Source: `lua/config/keymaps.lua`

### Movement And Editing

| Mode  | Key      | Action                                              | Note                           |
| ----- | -------- | --------------------------------------------------- | ------------------------------ |
| `n,v` | `<Up>`   | Move up by screen line                              | Uses `gk`                      |
| `n,v` | `<Down>` | Move down by screen line                            | Uses `gj`                      |
| `i`   | `<Up>`   | Move up by screen line                              | Uses `<C-o>gk`                 |
| `i`   | `<Down>` | Move down by screen line                            | Uses `<C-o>gj`                 |
| `n`   | `<A-j>`  | Move the current line down                          | Re-indents with `==`           |
| `n`   | `<A-k>`  | Move the current line up                            | Re-indents with `==`           |
| `i`   | `<A-j>`  | Move the current line down                          | Returns to insert with `gi`    |
| `i`   | `<A-k>`  | Move the current line up                            | Returns to insert with `gi`    |
| `v`   | `<A-j>`  | Move the selected block down                        | Keeps the selection, re-indents |
| `v`   | `<A-k>`  | Move the selected block up                          | Keeps the selection, re-indents |
| `n,x` | `<A-h>`  | Move the line or block left                         | From `mini.move`               |
| `n,x` | `<A-l>`  | Move the line or block right                        | From `mini.move`               |
| `n`   | `O`      | Add empty line above without staying in insert mode | Overrides default `O` behavior |
| `n`   | `o`      | Add empty line below without staying in insert mode | Overrides default `o` behavior |
| `n,v` | `x`      | Delete without yanking to default register          | Uses black-hole register       |
| `n,v` | `X`      | Delete backward without yanking to default register | Uses black-hole register       |
| `n,x` | `g<C-g>` | Disabled                                            | Prevents built-in cursor info popup |
| `n`   | `<leader>ui` | Show cursor info                                | Uses `vim.show_pos()`          |
| `n`   | `<leader>sk` | Toggle screenkey                                  | Shows or hides keystroke overlay |

To move a block, select it with `V` first; `<A-j>`/`<A-k>` keep the selection
(`gv=gv`) so the keys can be held down, and re-indent the block where it lands.
For a longer jump there is `:m +5` / `:m -3` in normal mode, or `:'<,'>m '>+5`
on a selection.

`mini.move` binds all four directions itself, but it is set up while
`config/lazy.lua` runs, and `keymaps.lua` is read after that -- so `<A-j>` and
`<A-k>` are the `:m` mappings above, and only `<A-h>`/`<A-l>` are still
`mini.move`'s.

### Multiple Cursors

`<C-d>` works the way it does in VS Code and Sublime Text: the first press
selects the word under the cursor, and every press after that adds a cursor at
the next occurrence. Type once and the change lands in all of them. `<Esc>`
collapses back to a single cursor.

| Mode  | Key             | Action                            | Note                                  |
| ----- | --------------- | --------------------------------- | ------------------------------------- |
| `n`   | `<C-d>`         | Select the word under the cursor  | Replaces the built-in half-page scroll |
| `x`   | `<C-d>`         | Add a cursor at the next match    | Repeat to keep adding                 |
| `n,x` | `<C-S-d>`       | Skip this match, take the next    | GUI only                              |
| `n,x` | `<C-S-l>`       | Add a cursor at every match       | GUI only                              |
| `n,x` | `<C-M-Up>`      | Add a cursor on the line above    | GUI only                              |
| `n,x` | `<C-M-Down>`    | Add a cursor on the line below    | GUI only                              |
| `n`   | `<M-LeftMouse>` | Add or remove a cursor at the pointer | Ctrl+click is go-to-definition    |
| `n,x` | `<leader>md`    | Add a cursor at the next match    |                                       |
| `n,x` | `<leader>mD`    | Add a cursor at the previous match |                                      |
| `n,x` | `<leader>ms`    | Skip to the next match            |                                       |
| `n,x` | `<leader>mS`    | Skip to the previous match        |                                       |
| `n,x` | `<leader>ma`    | Add a cursor at every match       |                                       |
| `n,x` | `<leader>mj`    | Add a cursor on the line below    |                                       |
| `n,x` | `<leader>mk`    | Add a cursor on the line above    |                                       |
| `n,x` | `<leader>mt`    | Disable or re-enable the cursors  | Only the main cursor keeps moving     |
| `n`   | `<leader>mr`    | Restore cursors cleared by mistake |                                      |

These only exist while more than one cursor is alive:

| Mode  | Key            | Action                        |
| ----- | -------------- | ----------------------------- |
| `n`   | `<Esc>`        | Collapse back to one cursor   |
| `n,x` | `<C-Left>`     | Make the previous cursor the main one |
| `n,x` | `<C-Right>`    | Make the next cursor the main one |
| `n,x` | `<leader>mx`   | Delete the main cursor        |

`<C-S-d>`, `<C-S-l>` and `<C-M-Up>`/`<C-M-Down>` only reach Neovim from a GUI
such as Neovide, or from a terminal that speaks the kitty keyboard protocol.
The `<leader>m` mappings do the same things everywhere.

Losing `<C-d>` costs the built-in half-page scroll down; `<C-f>`/`<C-b>` page
and `<C-e>`/`<C-y>` scroll by line. The dashboard's own `<C-d>` is buffer-local
and still forgets the recent file under the cursor.

### Buffers

| Mode  | Key            | Action               |
| ----- | -------------- | -------------------- |
| `n,i` | `<C-Tab>`      | Next buffer tab      |
| `n,i` | `<C-S-Tab>`    | Previous buffer tab  |
| `n`   | `<leader>w`    | Save current buffer  |
| `n`   | `<leader>q`    | Smart quit current buffer |
| `n`   | `<leader>x`    | Save and smart quit current buffer |
| `n`   | `<leader>bd`   | Delete current buffer |

### Command Line

| Mode | Key         | Action                    |
| ---- | ----------- | ------------------------- |
| `n`  | `:`         | Show reminder to use `<leader>:` |
| `n`  | `<leader>:` | Open fine command line    |

### Explorer

| Mode | Key         | Action                  |
| ---- | ----------- | ----------------------- |
| `n`  | `<leader>e` | Toggle `neo-tree` sidebar |

### Media Files

Images, audio and video go to the system player instead of being read into a
buffer. Neovim cannot render any of them, so loading one only fills the window
with binary noise and leaves a buffer to close again.

The hook is a `BufReadCmd` in `lua/config/media.lua`, which replaces the read
itself — so it catches every route to a file: `:edit`, neo-tree, fzf-lua, a
command-line argument, or a folder dropped on Neovide. The file is handed to
`vim.ui.open`, which is the same thing `gx` uses, so each type opens in whatever
Windows is set to open it with. The buffer Neovim made for it is taken apart
again, leaving the window on the file that was there before.

| Kind  | Extensions |
| ----- | ---------- |
| Image | `png` `jpg` `jpeg` `gif` `bmp` `webp` `ico` `tif` `tiff` `avif` `heic` |
| Audio | `mp3` `wav` `flac` `ogg` `oga` `m4a` `aac` `wma` `opus` |
| Video | `mp4` `mkv` `avi` `mov` `wmv` `webm` `flv` `m4v` `mpg` `mpeg` |

`svg` is deliberately absent: it is text, and editing one is a normal thing to
want to do. Case does not matter — `photo.JPG` is matched too.

`:MediaOpen [file]` opens a file in the player on demand, defaulting to the
current buffer. To get the raw bytes of a media file instead, set
`vim.g.media_autoopen = false` and open it again.

### Auto Save

A modified file is written back on **leaving insert mode**, on **moving to
another buffer or window**, and when **Neovim loses focus**. Nothing is written
while you are still typing, so the cursor never moves under you.

Autosave deliberately **does not format**. conform.nvim formats on
`BufWritePre`, and having clang-format reflow half-written code every time you
press `<Esc>` is not useful — `<leader>w` / `:w` still formats as before.
`lua/config/autosave.lua` flips conform's own `b:disable_autoformat` for the
duration of the write and restores whatever was there before, so a manual
`:FormatToggle!` is not lost.

Skipped: anything that is not a real file (terminals, help, the panels, scratch
buffers), read-only and unmodifiable buffers, unnamed buffers, files under a
directory that does not exist yet, and `gitcommit` / `gitrebase`, which are
written by hand on purpose.

| Command             | Action                                            |
| ------------------- | ------------------------------------------------- |
| `:AutoSaveToggle`   | Turn autosave off / on globally                   |
| `:AutoSaveToggle!`  | Same, for this buffer only                        |
| `:AutoSaveNow`      | Write the way autosave does, without formatting   |

`vim.g.autosave_disable` and `vim.b.autosave_disable` are the same switches.

### LSP

Only useful when an LSP server is attached to the current buffer.

| Mode | Key          | Action                   |
| ---- | ------------ | ------------------------ |
| `n`  | `gd`         | Goto definition          |
| `n`  | `gD`         | Goto declaration         |
| `n`  | `K`          | Hover documentation      |
| `n`  | `[d` / `]d`  | Previous / next diagnostic |
| `n`  | `<leader>rn` | Rename symbol            |
| `n`  | `<leader>la` | Code action              |
| `n`  | `<leader>lf` | Format buffer            |
| `n`  | `<leader>lh` | Switch source / header (`clangd`) |
| `n`  | `<leader>ln` | Toggle inlay hints       |
| `n`  | `<leader>ld` | FZF LSP definitions      |
| `n`  | `<leader>lr` | FZF LSP references       |
| `n`  | `<leader>li` | FZF LSP implementations  |
| `n`  | `<leader>lt` | FZF LSP typedefs         |
| `n`  | `<leader>ls` | FZF document symbols     |
| `n`  | `<leader>lS` | FZF workspace symbols    |
| `n`  | `<leader>lx` | FZF document diagnostics |
| `n`  | `<leader>lq` | FZF quickfix list        |

### C and C++ Functions

Treesitter, not LSP: these work in a header `clangd` has never opened.

| Mode | Key          | Command            | Action                                        |
| ---- | ------------ | ------------------ | --------------------------------------------- |
| `n`  | `<leader>lo` | `:CppImplement`    | Write the definition for the declaration under the cursor |
| `x`  | `<leader>lo` | `:CppImplement`    | Same, for every declaration in the selection  |
| `n`  | `<leader>lO` | `:CppImplementAll` | Write every definition the class under the cursor is missing |
| `n`  | `<leader>le` | `:CppSignature`    | Edit the signature here and apply it on the other side |

The generated definition goes into the matching source file (`clangd`'s own
source/header pairing when it is attached, an `include/` <-> `src/` guess
otherwise), qualified with its namespaces and class, without `virtual`,
`explicit`, `override` or default arguments, and the cursor lands inside the
new body. If there is no source file yet, one is created next to the header
with the right `#include`. Templates are defined in the header, after the
class, because that is where they have to live. Pure virtual, `= delete`,
`= default` and already-defined functions are skipped and reported.

`<leader>le` pre-fills the prompt with the current signature; what you type is
written back verbatim here, and the declaration or definition on the other side
is rewritten to match -- keeping its own `virtual`/`static`/`inline`,
`override` and `Class::` qualifier, and taking the new return type, name,
parameters and `const`/`noexcept`. The body is not touched. When the other file
is not open, it is written straight to disk without running format-on-save.

`{` placement follows whatever the target file already does; set
`vim.g.cpp_brace_style` to `"attach"` or `"next_line"` to force it.

### FZF

| Mode | Key          | Action            |
| ---- | ------------ | ----------------- |
| `n`  | `<leader>ff` | Find files        |
| `n`  | `<leader>fg` | Live grep         |
| `n`  | `<leader>fw` | Grep current word |
| `n`  | `<leader>fb` | Find buffers      |
| `n`  | `<leader>fo` | Find old files    |
| `n`  | `<leader>fh` | Search help tags  |
| `n`  | `<leader>fk` | Find keymaps      |
| `n`  | `<leader>fc` | Open cheatsheet   |

### Mouse

`mouse = a`, so the mouse works in every mode. In a terminal emulator Neovim now
captures the mouse — use `Shift`+drag if you want the terminal's own selection.
Neovide is unaffected.

| Action                    | Result                                             |
| ------------------------- | -------------------------------------------------- |
| Left click                | Place the cursor                                    |
| Left drag                 | Visual selection                                    |
| `Shift` + left click      | Extend the selection                                |
| Double click              | Select word · in the explorer, open the file        |
| Right click               | Context menu, on whatever was clicked               |
| `Ctrl` + left click       | Go to definition                                    |
| `Ctrl` + right click      | Jump back                                           |
| Mouse back / forward      | Walk the jump list (`<C-o>` / `<C-i>`)              |
| Scroll wheel              | 3 lines vertically, 6 columns horizontally          |
| Middle click (explorer)   | Open the file in a split                            |
| Middle click (buffer tab) | Close that buffer                                   |
| Right click (buffer tab)  | Close / Close Others / Copy Path / Reveal           |
| Right click (terminal)    | Paste                                               |

The right-click menu is built per buffer in `lua/config/mouse.lua`:

- **In a file** — Cut, Copy, Paste, Delete, Select All · Go to Definition, Find
  References, Rename Symbol, Code Action, Format Buffer · Show Diagnostics,
  Inspect Highlight · Copy Full Path, Copy Relative Path, Reveal in Explorer,
  Terminal Here. LSP entries are greyed out when no server is attached.
- **In the explorer** — Open (+ split / vsplit / tab) · New File, New Folder,
  Rename · Cut, Copy, Paste, Duplicate, Move · Delete, Move to Recycle Bin ·
  Copy Full Path, Copy Relative Path, Reveal in Explorer, Terminal Here ·
  Open as Project, **Add as Project**, **Forget Project**, Projects…,
  Set as Explorer Root, Refresh.
- **In a panel** — Open, Forget, Reveal in Explorer, Add Folder… / Open File…, Close.

The editor menu also ends with **Projects…**, **Recent Files…**, **Add This
Project** and **Forget This Project**, so projects and recent files can be
managed without touching the keyboard.

A click on a bufferline tab always opens the file in an editor window, never in
whatever float happens to be focused. bufferline's default is `buffer %d`, which
runs in the current window: with the toggleterm overlay up, the file was loaded
into the overlay, toggleterm lost track of its own window, and the next
`<leader>t` opened a second float while the first stayed on screen for good.

The dashboard is clickable too: `dashboard-nvim` ships no mouse bindings, so
this config adds them — a click opens the recent file on that row, or runs the
shortcut it landed on, resolved by column since the whole shortcut row is one
line. `<CR>` does the same under the cursor. Its *Most Recent Files* list is the
same list as the panel's, and `<C-d>` forgets the file under the cursor.
(`<C-d>` and not `d`: the theme hands every letter out as an entry hotkey.)

Both go through this config's own handler rather than the theme's, which parses
the path out of whatever line it is given and errors on a line with letters but
no punctuation — the footer, or `empty files` once every recent file has been
forgotten.

### Clipboard Keys

Windows-style keys, restricted to the modes where nothing is lost. Normal mode is
untouched, so `<C-v>` is still visual block.

| Mode | Key     | Action                                    |
| ---- | ------- | ----------------------------------------- |
| `x`  | `<C-c>` | Copy the selection to the system clipboard |
| `x`  | `<C-x>` | Cut the selection                          |
| `x`  | `<C-v>` | Paste over the selection                   |
| `i`  | `<C-v>` | Paste verbatim (no re-indent)              |
| `i`  | `<C-q>` | Insert a literal character (what `<C-v>` used to do) |
| `c`  | `<C-v>` | Paste into the command line                |
| `t`  | `<C-v>` | Paste into the terminal                    |

### Neovide

Configured in `lua/config/neovide.lua`; the whole module is a no-op under the
terminal UI.

| Mode      | Key                  | Action              |
| --------- | -------------------- | ------------------- |
| `n` `v` `i` | `<C-=>` / `<C-+>`  | Zoom in             |
| `n` `v` `i` | `<C-->`            | Zoom out            |
| `n` `v` `i` | `<C-0>`            | Reset zoom          |
| `n` `v` `i` | `Ctrl` + scroll    | Zoom in / out       |
| `n` `v` `i` | `<F11>`            | Toggle fullscreen   |

Also `:NeovideZoomReset` and `:NeovideFullscreen`.

The GUI font is `JetBrainsMono NFM`, falling back to `JetBrains Mono` and
`Cascadia Mono`. Nerd Fonts v3 installs the Windows-compatible families as
`JetBrainsMono NF` / `NFM` / `NFP` — the name `JetBrainsMono Nerd Font` does
*not* exist on this machine and would silently fall back to a font with no
icons. `NFM` is the Mono variant, so every glyph stays one cell wide and
neo-tree and bufferline keep their alignment.

Window size and position are remembered between sessions, IME input stays
enabled (needed for Vietnamese and CJK typing), and the idle refresh rate drops
to 5 Hz so a background window does not burn the GPU.

Dragging a file onto the window opens it; dragging a folder opens it as a
project. `:NeovideRegisterRightClick` adds an "Open with Neovide" entry to the
Windows Explorer context menu — for files only, not folders.

### Projects

Backed by `lua/config/projects.lua`. The recent-project list lives in
`stdpath("data")/projects/projects.json` and fills itself: every file you open
records the project root that owns it. Sessions are stored per project and saved
automatically when Neovim exits.

| Mode | Key          | Action                                        |
| ---- | ------------ | --------------------------------------------- |
| `n`  | `<leader>pp` | Pick a recent project (`ctrl-d` removes one)  |
| `n`  | `<leader>pm` | Project panel — the mouse-driven list          |
| `n`  | `<leader>pa` | Add the current project to the list           |
| `n`  | `<leader>pd` | Remove the current project from the list      |
| `n`  | `<leader>pr` | `cd` to the root of the current buffer        |
| `n`  | `<leader>pf` | Find files from the project root              |
| `n`  | `<leader>pg` | Live grep from the project root               |
| `n`  | `<leader>ps` | Save the session for this project             |
| `n`  | `<leader>pl` | Load the session for this project             |
| `n`  | `<leader>pD` | Delete the session for this project           |

The same actions are available as commands: `:ProjectOpen [dir]`, `:ProjectAdd`,
`:ProjectRemove`, `:ProjectRoot`, `:ProjectPanel`, `:ProjectSessionSave`,
`:ProjectSessionLoad`, `:ProjectSessionDelete`. Recent files have
`:RecentFiles`, `:RecentForget [file]`, `:RecentClear` and `:RecentReset`.

#### The clickable panels

Two floating lists share the same widget (`lua/config/panel.lua`) and the same
interaction model:

- **Projects** — `<leader>pm`, `:ProjectPanel`, or right-click → **Projects…**
- **Recent files** — `<leader>fr`, `:RecentFiles`, or right-click → **Recent Files…**

| Click                  | Result                                              |
| ---------------------- | --------------------------------------------------- |
| A row                  | Open that project / file                            |
| The `✕` at the row end | Forget it — nothing on disk is ever touched         |
| `+ Add folder…` / `+ Open file…` | Opens the native Windows picker dialog    |
| Right click            | Open / Forget / Reveal in Explorer / Add / Close    |
| Anywhere outside       | Close the panel                                     |

Keyboard equivalents inside a panel: `<CR>` open, `d` forget, `a` add, `q` or
`<Esc>` close. Rows are elided from the left when a path is long, so the `✕`
always stays inside the window. Opening one panel closes the other.

#### What "forget" means for a recent file

`v:oldfiles` is Neovim's own history, rebuilt from shada on every start, so it
is never rewritten. Forgetting adds the file to a persisted exclusion list
instead, and **opening the file again clears that exclusion**, so it returns to
the list on its own. `:RecentClear` hides everything currently listed and
`:RecentReset` undoes every exclusion.

The exclusion applies to the start screen as well: `dashboard-nvim` reads
`v:oldfiles` directly, which would show forgotten files again on every launch,
so `lua/plugins/dashboard.lua` replaces its `get_mru_list` with
`config.recent.list()`.

Files opened during the current session are tracked separately and merged in
front of `v:oldfiles`, so they show up immediately — `v:oldfiles` alone would
not list them until the next restart.

Root detection looks for, in order: `CMakePresets.json`, `CMakeLists.txt`,
`compile_commands.json`, `.clangd`, `meson.build`, `Makefile`, `.luarc.json`,
`.git`.

**Opening a folder opens it as a project.** That covers `nvim D:\some\project`,
`:edit <dir>`, `:ProjectOpen <dir>`, and dragging a folder onto the Neovide
window — Neovide turns the drop into `:drop <path>`, and any directory buffer is
turned into a project switch. Dragging a *file* onto Neovide just opens that
file, and its project is recorded automatically.

### Git

Repository-wide pickers, from `fzf-lua`:

| Mode | Key          | Action           |
| ---- | ------------ | ---------------- |
| `n`  | `<leader>gf` | Git files        |
| `n`  | `<leader>gs` | Git status       |
| `n`  | `<leader>gc` | Git commits      |
| `n`  | `<leader>gb` | Git branches     |
| `n`  | `<leader>gh` | Git file history |

Hunk-level work in the current buffer, from `gitsigns.nvim`. These are set in an
`on_attach`, so they only exist in a buffer that belongs to a repository.

| Mode   | Key          | Action                                    |
| ------ | ------------ | ----------------------------------------- |
| `n`    | `]c` / `[c`  | Next / previous hunk                      |
| `n`    | `<leader>ga` | Stage hunk — again on a staged hunk unstages it |
| `v`    | `<leader>ga` | Stage the selected lines                  |
| `n`    | `<leader>gr` | Reset hunk                                |
| `v`    | `<leader>gr` | Reset the selected lines                  |
| `n`    | `<leader>gA` | Stage buffer                              |
| `n`    | `<leader>gR` | Reset buffer                              |
| `n`    | `<leader>gp` | Preview hunk in a float                   |
| `n`    | `<leader>gl` | Blame the current line                    |
| `n`    | `<leader>gB` | Toggle the inline blame annotation        |
| `n`    | `<leader>gd` | Diff against the index                    |
| `n`    | `<leader>gD` | Diff against the last commit              |
| `o` `x`| `ih`         | Select the hunk under the cursor          |

`]c` / `[c` keep their built-in diff-mode meaning in a window that is actually
in diff mode, so they still work inside `<leader>gd`.

The statusline's diff counts come from gitsigns rather than a separate
`git diff`, so they include changes in a buffer that has not been written yet.

### CMake

These mappings call `cmake-tools.nvim` commands and will only work when those commands are available.

| Mode | Key          | Action                              |
| ---- | ------------ | ----------------------------------- |
| `n`  | `<leader>cc` | CMake configure                     |
| `n`  | `<leader>cb` | CMake build                         |
| `n`  | `<leader>cr` | CMake run                           |
| `n`  | `<leader>ct` | Select CMake build target           |
| `n`  | `<leader>cs` | Select CMake launch target          |
| `n`  | `<leader>cp` | Select CMake preset or fallback kit |
| `n`  | `<leader>cv` | Select CMake build type             |
| `n`  | `<leader>ck` | CMake clean                         |
| `n`  | `<leader>cT` | CMake run tests                     |
| `n`  | `<leader>cq` | Stop the running CMake task         |
| `n`  | `<leader>cn` | Scaffold a new CMake project (`CMakeQuickStart`) |

### Dropbar

| Mode | Key         | Action                         |
| ---- | ----------- | ------------------------------ |
| `n`  | `<leader>;` | Pick symbols in winbar         |
| `n`  | `[;`        | Go to start of current context |
| `n`  | `];`        | Select next context            |

### Mini Surround

| Mode | Key  | Action                       |
| ---- | ---- | ---------------------------- |
| `n`  | `sn` | Update surround search lines |

### Toggleterm

Configured in `lua/plugins/toggleterm.lua`.

| Mode | Key         | Action                                         |
| ---- | ----------- | ---------------------------------------------- |
| `n`  | `<leader>t` | Toggle floating terminal                       |
| `t`  | `<Esc>`     | Leave terminal mode                            |
| `t`  | `<C-h>`     | Move to left window                            |
| `t`  | `<C-j>`     | Move to lower window                           |
| `t`  | `<C-k>`     | Move to upper window                           |
| `t`  | `<C-l>`     | Move to right window                           |
| `t`  | `<C-w>`     | Enter normal window command mode from terminal |

### Which Key

Configured in `lua/plugins/which-key.lua`.

| Mode | Key         | Action                                   |
| ---- | ----------- | ---------------------------------------- |
| `n`  | `<leader>?` | Show buffer-local keymaps with which-key |

## Plugin Default Keymaps Worth Knowing

These are not manually mapped in `lua/config/keymaps.lua`, but they come from plugin setup.

### blink.cmp

Configured with `preset = "super-tab"`.

| Mode | Key       | Action                                         |
| ---- | --------- | ---------------------------------------------- |
| `i`  | `<Tab>`   | Accept or move through completion/snippet flow |
| `i`  | `<S-Tab>` | Move backward through completion/snippet flow  |
| `i`  | `<CR>`    | Confirm selected completion item               |

Note: exact behavior depends on completion visibility and snippet state.

### mini.surround

Configured in `lua/plugins/mini.lua`.

| Mode  | Key  | Action                 |
| ----- | ---- | ---------------------- |
| `n,v` | `sa` | Add surrounding        |
| `n`   | `sd` | Delete surrounding     |
| `n`   | `sf` | Find right surrounding |
| `n`   | `sF` | Find left surrounding  |
| `n`   | `sh` | Highlight surrounding  |
| `n`   | `sr` | Replace surrounding    |

## Quick Notes

- `K` and `<leader>rn` depend on LSP being attached to the current buffer.
- Dynamic line numbers are enabled: relative numbers disappear in insert mode and on inactive windows.
- `o` and `O` were remapped, so they no longer leave you in insert mode.
- `x` and `X` were remapped to the black-hole register, so they do not overwrite your default yank register.
- `clipboard = unnamedplus` is enabled, so normal yank and paste usually integrate with the system clipboard.
- `g<C-g>` was disabled; use `<leader>ui` for cursor position info instead.
- `<C-Tab>` and `<C-S-Tab>` switch buffers through `bufferline.nvim`.
- `<leader>w`, `<leader>q`, and `<leader>x` provide quick save / smart quit / save-and-quit shortcuts.
- `<leader>bd` currently runs `:bdelete`.
- `:` is blocked in normal mode and shows a reminder to use `<leader>:` instead.
- `<leader>:` opens `fine-cmdline.nvim` in a floating window.
- `<leader>e` toggles `neo-tree`, and the sidebar also opens automatically on startup outside the dashboard.
- FZF mappings call `fzf-lua`.
- Use `<leader>fc` to open this cheatsheet directly.
- Use `<leader>fk` to search keymaps from inside Neovim instead of opening this cheatsheet.
- `which-key.nvim` also shows key hints automatically when you pause after pressing `<leader>`.
- Use `<leader>?` when you want a focused popup of buffer-local mappings.
- CMake mappings depend on `cmake-tools.nvim` commands being available.
- `<leader>t` opens `toggleterm.nvim` as a floating terminal, and the terminal-mode mappings only apply inside toggleterm buffers.
- `screenkey.nvim` is off by default; use `<leader>sk` to toggle it when needed.
- GLSL-related extensions like `.vert`, `.frag`, `.geom`, `.comp`, `.tesc`, `.tese`, `.rgen`, `.mesh`, and `.task` are detected as `glsl`.
- C, C++, GLSL, and CMake buffers use 2-space indentation. GLSL uses `//` comments.
- Lua and Python buffers use 4-space indentation, matching `stylua` and PEP 8 so a save does not re-indent what you typed. Python keeps Neovim's own `indentexpr` rather than the Treesitter one, which does not handle `elif`/`else` dedents.
- `<leader>lo` / `<leader>lO` / `<leader>le` generate definitions and change signatures from the Treesitter tree, so they do not wait for `clangd`.
- `clangd` is configured for single-file C/C++ and reads `compile_commands.json` after CMake generate (`<leader>cc` copies it to the project root on Windows).
- Language servers: `clangd` (C/C++), `neocmake` (CMake), `glsl_analyzer` (shaders), `lua_ls` (Lua), `basedpyright` + `ruff` (Python). All are installed through `mason.nvim`.
- Python is served by two servers at once: `basedpyright` for types/hover/goto (import sorting disabled) and `ruff` for lint and fixes (hover disabled), so `K` and `<leader>w` never do the same job twice.
- Lua completion and `vim.*` types come from `lazydev.nvim`, which loads a library path only when a buffer mentions it; `lua_ls`'s own formatter is off so `stylua` owns Lua layout.
- Formatting on save: `clang-format` for C/C++ and GLSL (GLSL is passed `--assume-filename=shader.c` so clang-format knows the language), `stylua` for Lua, `cmake-format` for CMake, `ruff` for Python (`ruff_fix` -> `ruff_organize_imports` -> `ruff_format`). `:FormatToggle` turns it off globally, `:FormatToggle!` for the current buffer only.
- Treesitter parsers are compiled by the `tree-sitter` CLI, installed by `mason-tool-installer`. Run `:TSEnsure` if a parser is missing.
- `<leader>pp` opens the recent-project picker; the dashboard `p` shortcut does the same thing.
- Right-click works everywhere; the menu changes to a file-manager menu inside `neo-tree`.
- `netrw` is fully disabled: directory buffers belong to the project manager now.
- Dropping a folder on the Neovide window switches project; dropping a file opens it.
- Neovide zoom is `<C-=>` / `<C-->` / `<C-0>` or `Ctrl`+scroll; `<F11>` toggles fullscreen.
