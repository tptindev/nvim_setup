# Neo-tree Explorer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a VS Code-like project explorer that can auto-open for projects, toggle on demand, and appear immediately when opening a project from the dashboard.

**Architecture:** Add a dedicated `neo-tree` plugin spec so explorer behavior stays isolated from dashboard logic. Update the dashboard project action to change the local working directory and then open Neo-tree rooted at the selected folder.

**Tech Stack:** Neovim Lua config, lazy.nvim plugin specs, `neo-tree.nvim`

---

### Task 1: Register Neo-tree

**Files:**
- Create: `docs/superpowers/plans/2026-04-01-neo-tree-explorer.md`
- Create: `lua/plugins/neo-tree.lua`
- Modify: `lua/plugins/init.lua`

- [ ] Add a plugin spec for `neo-tree.nvim` with dependencies and setup.
- [ ] Register the plugin in the plugin init list.

### Task 2: Connect dashboard project opening

**Files:**
- Modify: `lua/plugins/dashboard.lua`

- [ ] Update the project picker action so selecting a folder changes the local cwd.
- [ ] Open Neo-tree for the selected folder after the dashboard action runs.

### Task 3: Verify configuration

**Files:**
- Verify: `lua/plugins/neo-tree.lua`
- Verify: `lua/plugins/init.lua`
- Verify: `lua/plugins/dashboard.lua`

- [ ] Run a Lua syntax check over the edited files.
- [ ] Review the final behavior for startup, toggle, and dashboard project opening.
