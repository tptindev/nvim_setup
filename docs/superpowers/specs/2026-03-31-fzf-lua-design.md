# Fzf-Lua Neovim Configuration Design

**Date:** 2026-03-31

## Goal

Add `ibhagwan/fzf-lua` to this Neovim configuration with a complete daily-driver setup that prioritizes project navigation, while also covering common LSP and Git workflows.

## Current Context

The current config keeps plugin declarations in small files under `lua/plugins/`, aggregates them in `lua/plugins/init.lua`, and defines keymaps centrally in `lua/config/keymaps.lua`.

Relevant existing files:

- `init.lua` loads `config.options`, `config.lazy`, and `config.keymaps`
- `lua/plugins/init.lua` returns a list of `require("plugins.<name>")`
- `lua/config/keymaps.lua` currently contains `dropbar` mappings only

## Recommended Approach

Create a dedicated `lua/plugins/fzf.lua` plugin spec and register it from `lua/plugins/init.lua`. Keep all `fzf-lua` keymaps in `lua/config/keymaps.lua` so the repo continues to separate plugin declaration from interaction behavior.

This approach follows the current structure, keeps the plugin self-contained, and avoids introducing a new mapping pattern that would be harder to maintain later.

## Alternatives Considered

### 1. Minimal plugin-only setup

Install `fzf-lua` with little or no configuration and rely mostly on defaults.

Trade-off: fast to add, but it does not deliver the full navigation, LSP, and Git workflow requested.

### 2. Full workflow setup inside the plugin spec

Put plugin options and all keymaps inside `lua/plugins/fzf.lua`.

Trade-off: it would work, but it would conflict with the repo's current organization where keymaps live in `lua/config/keymaps.lua`.

### 3. Recommended: split plugin spec and keymaps

Keep plugin configuration in `lua/plugins/fzf.lua` and usage bindings in `lua/config/keymaps.lua`.

Trade-off: changes span multiple files, but the structure stays consistent and easier to extend.

## Architecture

### Plugin registration

Add `require("plugins.fzf")` to `lua/plugins/init.lua`.

### Plugin spec

Create `lua/plugins/fzf.lua` with:

- plugin source `ibhagwan/fzf-lua`
- lazy loading via keys and commands
- optional dependency on `nvim-tree/nvim-web-devicons`
- a focused `opts` table for layout, preview, hidden file handling, and picker defaults

### Keymaps

Add a cohesive `fzf-lua` mapping set in `lua/config/keymaps.lua` that avoids existing `dropbar` mappings:

- Project navigation:
  - `<leader>ff` files
  - `<leader>fg` live grep
  - `<leader>fw` grep current word
  - `<leader>fb` buffers
  - `<leader>fo` oldfiles
  - `<leader>fh` help tags
- LSP:
  - `<leader>ld` definitions
  - `<leader>lr` references
  - `<leader>li` implementations
  - `<leader>lt` typedefs
  - `<leader>ls` document symbols
  - `<leader>lS` workspace symbols
  - `<leader>lx` diagnostics
  - `<leader>lq` quickfix
- Git:
  - `<leader>gf` git files
  - `<leader>gs` git status
  - `<leader>gc` git commits
  - `<leader>gb` git branches
  - `<leader>gh` file history

## Behavior Details

- Prefer hidden files in project file search, but continue to ignore `.git`
- Keep preview enabled for the common pickers
- Use a compact bordered window layout that feels intentional without diverging from the rest of the config
- Preserve startup performance by lazy-loading on use rather than forcing eager startup loading

## Error Handling

- Keymaps call `require("fzf-lua")` lazily so the plugin loads only when used
- LSP pickers depend on an attached language server; they should fail only in the normal way if no server is active
- Git pickers are expected to work inside repositories and may be less useful outside them

## Testing Plan

After implementation:

1. Start Neovim and confirm the config loads without startup errors
2. Trigger the primary project mappings:
   - `<leader>ff`
   - `<leader>fg`
   - `<leader>fb`
3. Open a file with LSP attached and verify at least `definitions`, `references`, and `document symbols`
4. Open a Git repository and verify at least `git files`, `git status`, and `git commits`

## Scope Boundaries

Included in this change:

- plugin installation
- core UI configuration
- navigation, LSP, and Git keymaps

Not included in this change:

- deep theme customization
- advanced picker-specific overrides for every command
- broader keymap refactors outside `fzf-lua`
