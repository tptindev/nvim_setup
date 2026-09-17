# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal Neovim configuration on Windows using lazy.nvim for plugin management. Targets C/C++, CMake, Lua, and GLSL workflows. Also supports Neovide.

## Running Tests

Tests are standalone Lua scripts in `tests/` using plain assert/error (no framework):

```bash
nvim --headless -u NONE -l tests/<test_file>.lua
```

Each test bootstraps its own `package.path` and exits via `vim.cmd("qa!")`.

## Architecture

**Boot sequence** (`init.lua` loads in this order):

1. `lua/config/options.lua` — editor settings, autocommands, filetype rules
2. `lua/config/lazy.lua` — bootstraps lazy.nvim, sets leader keys (`<Space>` / `\`), imports plugins
3. `lua/config/keymaps.lua` — all keybindings and user commands

**Plugin specs** are individual files in `lua/plugins/`, each returning a lazy.nvim spec table. They are explicitly required in `lua/plugins/init.lua` (not auto-discovered).

**Smart buffer management** (`lua/config/buffers.lua`) replaces built-in `:q`, `:bd`, `:wq` etc. via command abbreviations defined in `keymaps.lua`. Closing the last editor buffer creates a placeholder instead of quitting Neovim. When modifying buffer close/quit behavior, both `buffers.lua` and the abbreviation block in `keymaps.lua` must stay in sync.

**Project management** (`lua/config/projects.lua`) owns root detection, the recent-project list (JSON under `stdpath("data")/projects`), and per-project sessions. `keymaps.lua` calls `projects.setup()`, which registers the `:Project*` commands and the autocmd that records a project whenever a file is opened. The store location is overridable via `vim.g.projects_data_dir` so tests do not touch real data. `dashboard.lua` calls into this module rather than keeping its own project cache.

**Clickable panels** live in `lua/config/panel.lua`; `projects.lua` and `recent.lua` only supply entries and callbacks. Only one panel exists at a time, and `vim.b.panel_kind` tells `mouse.lua` which context menu to build. The panel is a float whose rows are clickable: `panel.rows` maps a buffer line to an action, and each project row stores `hit_col`, the byte offset where the `✕` starts, so a click past it means "forget" and anything before it means "open". Row text is elided so a row never exceeds the window width — if it does, the `✕` moves off screen and cannot be clicked. When testing clicks with `nvim_input_mouse`, redraw and yield first: mouse input is resolved against the last *painted* screen, so a click injected right after opening a float lands in the window underneath.

**Recent files** (`lua/config/recent.lua`) never rewrite `v:oldfiles` — that list is rebuilt from shada at startup, so edits to it are lost and a re-opened file could not come back. "Forget" is a persisted exclusion set that `BufReadPost` clears when the file is opened again. Files opened in the current session are tracked in-memory and merged ahead of `v:oldfiles`, which otherwise would not list them until the next restart.

**Recent files on the start screen**: `dashboard-nvim` builds its MRU list from `vim.v.oldfiles` directly (`dashboard/utils.lua`, `get_mru_list`) and offers no way to remove an entry, so a file forgotten through `recent.lua` would come back on every launch. `lua/plugins/dashboard.lua` overrides `get_mru_list` to return `config.recent.list()` and keeps the rendered list so `<C-d>` can map a dashboard row back to its path. The row is deleted in place rather than re-rendering the dashboard: a second `dashboard:instance()` re-saves the already-hidden `laststatus`/`showtabline` as if they were the user's values. Clicks and `<CR>` are handled by that file too, never delegated to the theme's own confirm key: it parses a path out of the raw line and `math.min(text:find('%w'), text:find('%p'))` throws on a line with letters but no punctuation (the footer, `empty files`). The shortcut row is a single line, so a click is resolved by rebuilding the byte spans `gen_shortcut` lays out; the `shortcut` table has to stay a `local` the handler can see.

**Bufferline tab clicks** go through `left_mouse_command` in `lua/plugins/bufferline.lua`, which picks a non-float, non-sidebar window before switching. The default `buffer %d` runs in the current window, so a tab click with the toggleterm float focused loaded the file into the float; `Terminal:is_open()` then returned false (it checks the window still shows its buffer), the next toggle opened a second float, and the orphan could only be closed with `<C-w>q` — `:q` in it hits `buffers.quit`, which sees a file buffer and deletes it. `winfixbuf` on the terminal window is not an alternative: bufferline's `buffer %d` against it crashed Neovim in testing.

**Autosave** (`lua/config/autosave.lua`) writes a modified file on `InsertLeave`, `BufLeave`, `WinLeave` and `FocusLost` — never while typing. It must not format: conform.nvim formats on `BufWritePre`, so autosave sets conform's own `b:disable_autoformat` for the duration of the write and restores the previous value, which keeps a manual `:FormatToggle!` intact. `keymaps.lua` calls `autosave.setup()`; `<leader>w` still formats.

**Git** is split in two. The `<leader>g` pickers in `keymaps.lua` are `fzf-lua` and work on the repository; `lua/plugins/gitsigns.lua` owns everything buffer-local and sets its keymaps in `on_attach`, so they only exist in a buffer inside a repository — the letters it uses are the ones `<leader>gf/gs/gc/gb/gh` left over. `]c`/`[c` check `vim.wo.diff` and fall through to the built-in diff motions, so they still work inside `:Gitsigns diffthis`. Attachment is asynchronous and finishes well after `BufReadPost`: `vim.b.gitsigns_status_dict` appears early with only `head`/`gitdir`/`root`, and the keymaps, signs and diff counts land later, so a test must wait on `require("gitsigns.cache").cache[buf]` rather than on the status dict. `lualine.lua` feeds its `diff` component from that status dict instead of letting lualine run its own `git diff`, which keeps the statusline counts in step with the gutter while a buffer is unwritten.

**Media files** (`lua/config/media.lua`) are handed to `vim.ui.open` rather than read into a buffer. The hook is a `BufReadCmd`, which replaces the read itself and so covers every route to a file (`:edit`, neo-tree, fzf-lua, an argument, a Neovide drop); the buffer Neovim created is dismissed on the next tick, falling back to the alternate buffer. Autocommand patterns are case-insensitive on Windows, so `*.png` plus `*.PNG` would fire the callback twice — the patterns are built as `*.[pP][nN][gG]` instead, one per extension. `keymaps.lua` calls `media.setup()`.

**Mouse** (`lua/config/mouse.lua`) owns the right-click menu. It clears Neovim's built-in `nvim.popupmenu` autocmd and rebuilds `PopUp` from scratch on every `MenuPopup`, choosing an editor menu or a `neo-tree` file-manager menu based on the buffer. `<RightMouse>` must stay unmapped for `mousemodel=popup_setpos` to fire, so never add a `<RightMouse>` mapping to a buffer that should show the menu.

**Opening a directory** is wired to "open that project": `projects.setup()` watches for directory buffers and hands them to `projects.open()`. This is also how a folder dropped on Neovide is handled (Neovide sends `:drop <path>`). `netrw` and neo-tree's `hijack_netrw_behavior` are both disabled so nothing else claims directory buffers.

**Neovide** settings live in `lua/config/neovide.lua`, required from `options.lua` so the font applies before the first frame. `setup()` returns early unless `vim.g.neovide` is set, and it owns the only GUI-specific keymaps in the config. Neovide picks up `vim.g.neovide_*` assigned from `init.lua` (verified: changing `neovide_padding_left` at runtime resizes the grid), so setting them there is correct. The font must name an installed family — Nerd Fonts v3 installs `JetBrainsMono NF`/`NFM`/`NFP`, never `JetBrainsMono Nerd Font`. `neovide_input_ime` is mode-aware rather than always on: with the IME holding the keys, it swallows `<Esc>` to cancel composition, so `<Esc>` never reaches Neovim and a buffer-local terminal mapping for it looks broken while `nvim_buf_get_keymap` still lists it — clicking another window only seemed to help because the focus change resets the IME. `InsertEnter`/`CmdlineEnter` hand the keys to the IME and `InsertLeave`/`CmdlineLeave`/`TermEnter` take them back; `TermEnter` is there because Neovim does not report terminal mode as insert. `:NeovideIme` overrides it for a terminal that really needs Vietnamese input, until the next mode change.

**LSP keymaps** are set via an `LspAttach` autocmd at the bottom of `keymaps.lua`, not in the lspconfig plugin spec.

**Treesitter** uses the `main` branch API (`require("nvim-treesitter").setup()` / `.install()`), which is incompatible with the legacy `master` branch — the spec pins `branch = "main"`. Parsers are compiled by the `tree-sitter` CLI that `mason-tool-installer` provides; the config skips installation with a warning when the CLI is absent rather than erroring on every startup.

## Key Conventions

- 2-space indentation, expand tabs (global default and C/C++ FileType autocmd)
- File format forced to Unix (`fileformat=unix`)
- Normal-mode `:` is remapped to a notification pointing to `<leader>:` (fine-cmdline). Don't add mappings relying on native `:` in normal mode.
- `O`/`o` insert blank lines without entering insert mode; `x`/`X` delete to black hole register
- Helper factories (`fzf()`, `cmake()`, `smart_write()`, `smart_quit()`) in keymaps.lua return callbacks; follow this pattern for new keymaps
