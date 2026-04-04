# Lualine Statusline Design

**Date:** 2026-04-05

## Goal

Add a `lualine.nvim` statusline that fits this Neovim config's current workflow: clear editing state, visible Git context, and practical coding signals without duplicating `bufferline` or `dropbar`.

## Current Context

This config already has a strong visual and workflow structure:

- `lua/plugins/colorscheme.lua` uses `kanagawa` with the `wave` theme
- `lua/plugins/bufferline.lua` already owns buffer navigation in the tabline
- `lua/plugins/dropbar.lua` is available for breadcrumb and code context in the winbar
- `lua/plugins/neo-tree.lua` keeps a persistent project sidebar open in normal editing sessions
- `lua/config/options.lua` sets `cmdheight = 0`, which makes the statusline more important as a stable source of session state
- the main workflow centers on C/C++, CMake, Lua, GLSL, Git, LSP, and diagnostics

Because buffer navigation and breadcrumbs are already handled elsewhere, the statusline should focus on session state rather than file structure or navigation redundancy.

## Recommended Approach

Use `nvim-lualine/lualine.nvim` with a `Focused IDE` layout:

- strong mode visibility
- branch and diff visible near the left side
- filename or relative path in the center-left
- diagnostics and active LSP client on the right
- filetype plus cursor position at the far right

This gives an IDE-like readout while staying calmer than a dense utility bar.

## Alternatives Considered

### 1. Dense Utility

Show more metadata such as project root, encoding, and fileformat all the time.

This is powerful, but it adds noise for a config that already exposes context through the sidebar, winbar, and editor defaults.

### 2. Recommended: Focused IDE

Keep the statusline centered on the most useful live signals: mode, Git, file state, diagnostics, LSP, filetype, and cursor position.

This best matches the repo's existing split of responsibilities across UI layers.

### 3. Minimal Zen

Strip the statusline down to mode, filename, and cursor position only.

This would look clean, but it under-serves the current build-oriented workflow where branch, diff, and diagnostics matter continuously.

## Architecture

### UI role split

- `bufferline` remains responsible for open-buffer navigation
- `dropbar` remains responsible for breadcrumb or code-context navigation
- `lualine` becomes the main surface for live status signals

### Section layout

Use these sections:

- `lualine_a`: mode
- `lualine_b`: branch and diff
- `lualine_c`: filename or relative path, plus modified and readonly markers
- `lualine_x`: diagnostics and active LSP client name
- `lualine_y`: filetype
- `lualine_z`: progress and line/column

### Visual style

- base the theme on `kanagawa wave`
- keep the background close to the existing palette rather than creating a high-contrast bar
- make mode the strongest highlight
- keep Git emphasis medium
- use semantic colors for diagnostics
- use subtle separators instead of heavy bubble or block styling
- fade inactive windows so secondary panes feel quieter

### Context rules

- do not show buffers or breadcrumbs in the statusline
- keep inactive windows minimal, showing only lightweight context such as filename and location
- do not show `encoding` by default
- do not show `fileformat` by default because the config already normalizes line endings
- only show LSP client information when a client is attached
- keep diagnostics compact as counts rather than verbose text

## Error Handling

- if no LSP client is attached, the LSP section should disappear cleanly rather than leaving placeholder text
- if a buffer has no Git data, branch and diff should simply be absent
- if diagnostics are unavailable, the diagnostics section should collapse without layout breakage
- if a special buffer type should not show the normal bar, the plugin config should disable lualine for that filetype

## Testing Plan

1. Add `lualine.nvim` as a plugin module in `lua/plugins/`
2. Register it in `lua/plugins/init.lua`
3. Start Neovim and verify the statusline loads with no startup errors
4. Check normal, insert, and visual mode transitions for clear mode highlighting
5. Open a Git-tracked file and verify branch and diff render correctly
6. Open an LSP-backed file and verify diagnostics and client name appear
7. Open inactive windows, dashboard, and special buffers to confirm the fallback or disabled behavior is correct

## Scope Boundaries

Included in this change:

- adding `lualine.nvim`
- creating a `Focused IDE` statusline layout
- surfacing branch and diff in a stable left-side position
- showing diagnostics and active LSP client when available
- matching the design to `kanagawa wave`

Not included in this change:

- replacing `bufferline`
- replacing `dropbar`
- adding custom build-status components from `cmake-tools.nvim`
- permanently showing encoding or fileformat metadata
