# More Mini.nvim Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `mini.move`, `mini.notify`, `mini.statusline`, and `mini.hipatterns` to the existing `mini.nvim` setup.

**Architecture:** Keep all `mini.nvim` configuration in `lua/plugins/mini.lua` so the suite remains centralized. Add the new modules with conservative defaults that match the current config style and avoid unnecessary cross-file changes.

**Tech Stack:** Neovim, lazy.nvim, Lua, mini.nvim

---

### Task 1: Expand the mini.nvim suite config

**Files:**
- Modify: `lua/plugins/mini.lua`

- [ ] Add `mini.move` with default `Alt-h/j/k/l` mappings.
- [ ] Add `mini.notify` and route `vim.notify` through it after setup.
- [ ] Add `mini.statusline` with a richer active statusline layout.
- [ ] Add `mini.hipatterns` highlighters for hex colors and note keywords.

### Task 2: Verify config

**Files:**
- Verify: `lua/plugins/mini.lua`

- [ ] Run a headless syntax/load check for the updated plugin config file.
