# Lotus Neovim Config

Personal Neovim configuration focused on a fast editing workflow, practical defaults, and a solid setup for C/C++, CMake, Lua, and GLSL work.

This repo uses `lazy.nvim` for plugin management and keeps the configuration split into small Lua modules under `lua/config` and `lua/plugins`.

## Highlights

- `lazy.nvim` bootstrap on startup
- `fzf-lua` for file, grep, buffer, help, LSP, and Git pickers
- `neo-tree.nvim` as the main file explorer
- `nvim-lspconfig` + `mason.nvim` + `mason-lspconfig.nvim` for LSP setup
- `blink.cmp` for completion with a `super-tab` workflow
- `nvim-treesitter` for syntax awareness
- `toggleterm.nvim` for a floating terminal
- `cmake-tools.nvim` shortcuts for configure, build, run, and target selection
- `which-key.nvim` for discoverable leader mappings
- `dashboard-nvim` with shortcuts for files, projects, settings, and recent work
- `screenkey.nvim` enabled by default, with auto-hide behavior for dashboard and terminal buffers

## Workflow

This configuration is built around a few main ideas:

- Fast fuzzy navigation with `fzf-lua`
- A persistent project sidebar with `neo-tree`
- IDE-style language support through LSP and completion
- Smooth terminal and build integration for CMake projects
- Discoverable keymaps with both `which-key` and a dedicated cheatsheet

## Default Behavior

Some notable editor defaults in this repo:

- `mapleader` is set to `<Space>`
- `maplocalleader` is set to `\`
- Relative numbers are enabled dynamically outside insert mode
- Wrapping is disabled
- Persistent undo is enabled
- Search is case-insensitive unless uppercase is used
- Clipboard uses `unnamedplus`
- Spell checking is enabled with `en_us`
- Neovide uses `JetBrainsMono Nerd Font`
- Common GLSL-related extensions are mapped to the `glsl` filetype

## Language Support

The current LSP setup ensures these servers are installed and enabled:

- `clangd`
- `lua_ls`
- `glsl_analyzer`

This makes the repo especially suitable for:

- C and C++
- CMake-based projects
- Lua
- GLSL shaders

## Keymaps

The main custom mappings live in `lua/config/keymaps.lua`.

Useful examples:

- `<leader>ff` to find files
- `<leader>fg` to live grep
- `<leader>e` to toggle the file explorer
- `<leader>t` to open the floating terminal
- `<leader>cc` / `<leader>cb` / `<leader>cr` for CMake configure, build, and run
- `<leader>?` to show buffer-local mappings with `which-key`

For a fuller list, see [docs/cheatsheet.md](docs/cheatsheet.md).

## Structure

```text
.
|-- init.lua
|-- lazy-lock.json
|-- docs/
|   `-- cheatsheet.md
`-- lua/
    |-- config/
    |   |-- keymaps.lua
    |   |-- lazy.lua
    |   `-- options.lua
    `-- plugins/
```

## Installation

1. Back up your current Neovim config if needed.
2. Clone or copy this repo to your Neovim config directory.
3. Start Neovim.
4. On first launch, `lazy.nvim` will bootstrap itself automatically.

Typical config locations:

- Windows: `%LOCALAPPDATA%\nvim` or `%USERPROFILE%\.config\nvim`
- Linux/macOS: `~/.config/nvim`

## Notes

- This is a personal config, so some choices are opinionated and tuned to the author's workflow.
- The repo includes planning and spec documents under `docs/superpowers/`, but the main user-facing reference is the cheatsheet.
- Some mappings and features depend on external tools being available in your environment, especially for LSP and CMake workflows.
