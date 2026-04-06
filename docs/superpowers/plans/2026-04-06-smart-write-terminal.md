# Smart Write Terminal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent `:w` on terminal/special buffers from leaving a stuck built-in error message under the statusline.

**Architecture:** Keep the fix inside `lua/config/keymaps.lua`, where command-line behavior and write shortcuts already live. Route write requests through a small helper that refuses non-file buffers and emits `vim.notify(...)` instead of Neovim's built-in `buftype` write error.

**Tech Stack:** Lua, Neovim user commands, command-line abbreviations, headless Neovim tests

---

### Task 1: Add a failing regression test

**Files:**
- Create: `tests/smart_write_terminal.lua`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run the test to confirm it fails before implementation**

### Task 2: Implement guarded write commands

**Files:**
- Modify: `lua/config/keymaps.lua`
- Test: `tests/smart_write_terminal.lua`

- [ ] **Step 1: Add a smart write helper for special buffers**
- [ ] **Step 2: Route normal-mode write mapping and `:w`/`:write` abbreviations through it**
- [ ] **Step 3: Re-run the targeted test until it passes**

### Task 3: Verify config health

**Files:**
- Modify: `lua/config/keymaps.lua`
- Test: `tests/smart_write_terminal.lua`

- [ ] **Step 1: Run the targeted regression test**
- [ ] **Step 2: Run a headless config smoke check**
