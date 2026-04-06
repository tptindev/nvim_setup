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

**LSP keymaps** are set via an `LspAttach` autocmd at the bottom of `keymaps.lua`, not in the lspconfig plugin spec.

## Key Conventions

- 2-space indentation, expand tabs (global default and C/C++ FileType autocmd)
- File format forced to Unix (`fileformat=unix`)
- Normal-mode `:` is remapped to a notification pointing to `<leader>:` (fine-cmdline). Don't add mappings relying on native `:` in normal mode.
- `O`/`o` insert blank lines without entering insert mode; `x`/`X` delete to black hole register
- Helper factories (`fzf()`, `cmake()`, `smart_write()`, `smart_quit()`) in keymaps.lua return callbacks; follow this pattern for new keymaps
