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

**Mouse** (`lua/config/mouse.lua`) owns the right-click menu. It clears Neovim's built-in `nvim.popupmenu` autocmd and rebuilds `PopUp` from scratch on every `MenuPopup`, choosing an editor menu or a `neo-tree` file-manager menu based on the buffer. `<RightMouse>` must stay unmapped for `mousemodel=popup_setpos` to fire, so never add a `<RightMouse>` mapping to a buffer that should show the menu.

**Opening a directory** is wired to "open that project": `projects.setup()` watches for directory buffers and hands them to `projects.open()`. This is also how a folder dropped on Neovide is handled (Neovide sends `:drop <path>`). `netrw` and neo-tree's `hijack_netrw_behavior` are both disabled so nothing else claims directory buffers.

**Neovide** settings live in `lua/config/neovide.lua`, required from `options.lua` so the font applies before the first frame. `setup()` returns early unless `vim.g.neovide` is set, and it owns the only GUI-specific keymaps in the config. Neovide picks up `vim.g.neovide_*` assigned from `init.lua` (verified: changing `neovide_padding_left` at runtime resizes the grid), so setting them there is correct. The font must name an installed family — Nerd Fonts v3 installs `JetBrainsMono NF`/`NFM`/`NFP`, never `JetBrainsMono Nerd Font`.

**LSP keymaps** are set via an `LspAttach` autocmd at the bottom of `keymaps.lua`, not in the lspconfig plugin spec.

**Treesitter** uses the `main` branch API (`require("nvim-treesitter").setup()` / `.install()`), which is incompatible with the legacy `master` branch — the spec pins `branch = "main"`. Parsers are compiled by the `tree-sitter` CLI that `mason-tool-installer` provides; the config skips installation with a warning when the CLI is absent rather than erroring on every startup.

## Key Conventions

- 2-space indentation, expand tabs (global default and C/C++ FileType autocmd)
- File format forced to Unix (`fileformat=unix`)
- Normal-mode `:` is remapped to a notification pointing to `<leader>:` (fine-cmdline). Don't add mappings relying on native `:` in normal mode.
- `O`/`o` insert blank lines without entering insert mode; `x`/`X` delete to black hole register
- Helper factories (`fzf()`, `cmake()`, `smart_write()`, `smart_quit()`) in keymaps.lua return callbacks; follow this pattern for new keymaps
