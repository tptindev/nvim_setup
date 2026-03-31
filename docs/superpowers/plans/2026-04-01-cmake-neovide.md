# CMake Support In Neovide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add CMake project workflow support to this Neovim configuration so Neovide can configure, build, run, and provide accurate `clangd` support for CMake-based C/C++ projects.

**Architecture:** Add a dedicated `cmake-tools.nvim` plugin spec, register it alongside the existing plugin list, and expose a focused set of CMake keymaps from the central keymap module. Keep `clangd` in the current LSP file, but tune it so it plays better with CMake-generated compile commands without forcing a single Windows generator.

**Tech Stack:** Neovim, Lua, lazy.nvim, mason.nvim, nvim-lspconfig, cmake-tools.nvim, clangd

---

### Task 1: Prepare isolated feature workspace

**Files:**
- Modify: `.gitignore`
- Create: `.worktrees/cmake-neovide/`

- [ ] Ensure `.worktrees/` is ignored by git so a local worktree will not pollute repository status.
- [ ] Commit the ignore rule before creating the worktree.
- [ ] Create the `cmake-neovide` branch in `.worktrees/cmake-neovide`.
- [ ] Verify the new worktree starts from a clean status baseline.

### Task 2: Add CMake workflow plugin

**Files:**
- Create: `lua/plugins/cmake.lua`
- Modify: `lua/plugins/init.lua`

- [ ] Add a lazy.nvim plugin spec for `Civitasv/cmake-tools.nvim`.
- [ ] Configure conservative defaults for configure/build/run on Windows, including preset-aware behavior and a stable build directory.
- [ ] Register the new plugin from the central plugin list.
- [ ] Keep the plugin config focused on plugin behavior rather than editor keybindings.

### Task 3: Add CMake editor keymaps

**Files:**
- Modify: `lua/config/keymaps.lua`

- [ ] Add user-facing keymaps for CMake configure, build, run, target selection, and configure preset or kit selection.
- [ ] Reuse the existing keymap style and descriptions so the new mappings feel native to this repo.
- [ ] Avoid collisions with the current leader mappings.

### Task 4: Tune clangd for CMake projects

**Files:**
- Modify: `lua/plugins/lspconfig.lua`

- [ ] Keep the current Mason + `vim.lsp.config` structure intact.
- [ ] Add `clangd` settings that cooperate better with CMake-generated compile commands while remaining flexible across `Ninja` and `MSVC`.
- [ ] Keep the Lua LSP setup unchanged except for any incidental formatting needed around the edit.

### Task 5: Verify the configuration

**Files:**
- Verify: `lua/plugins/cmake.lua`
- Verify: `lua/plugins/init.lua`
- Verify: `lua/config/keymaps.lua`
- Verify: `lua/plugins/lspconfig.lua`

- [ ] Run a headless Neovim load check for the updated configuration.
- [ ] Inspect git status to confirm only intended files changed in the feature branch.
- [ ] Summarize any remaining runtime prerequisites that cannot be verified from inside this repo, such as needing `cmake` and a project toolchain installed.
