# Block Default Colon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Block normal-mode `:` from opening the built-in command line and show a notification that teaches the user to use `<leader>:` instead.

**Architecture:** Keep the behavior change in `lua/config/keymaps.lua`, where the rest of the user keymaps already live. Add a focused headless test under `tests/` that inspects the mapping and executes its callback to verify the notification text.

**Tech Stack:** Lua, Neovim, headless Neovim test scripts

---

## File Structure

- Create: `docs/superpowers/specs/2026-04-04-block-default-colon-design.md`
- Create: `tests/colon_notify.lua`
- Modify: `lua/config/keymaps.lua`
- Modify: `docs/cheatsheet.md`

### Task 1: Add a failing keymap test

**Files:**

- Create: `tests/colon_notify.lua`

- [ ] **Step 1: Write a test that loads `config.keymaps`**

Set `package.path` so the test can require the local Lua modules without booting the full config.

- [ ] **Step 2: Assert the `:` normal-mode mapping exists**

Use `vim.fn.maparg(":", "n", false, true)` and expect a Lua callback-backed mapping.

- [ ] **Step 3: Assert the mapping notifies the user**

Override `vim.notify`, invoke the callback, and assert the message and log level are correct.

- [ ] **Step 4: Run the test and confirm it fails before implementation**

Run:

```bash
nvim --headless -u NONE -c "lua dofile('tests/colon_notify.lua')"
```

Expected: FAIL because no `:` mapping exists yet.

### Task 2: Implement the mapping

**Files:**

- Modify: `lua/config/keymaps.lua`

- [ ] **Step 1: Add a small helper for the notification**

Add a local function that calls:

```lua
vim.notify("Use <leader>: for fine command line", vim.log.levels.INFO)
```

- [ ] **Step 2: Map normal-mode `:`**

Add:

```lua
map("n", ":", notify_use_fine_cmdline, { desc = "Use fine command line" })
```

- [ ] **Step 3: Re-run the targeted test**

Run:

```bash
nvim --headless -u NONE -c "lua dofile('tests/colon_notify.lua')"
```

Expected: PASS with no error output.

### Task 3: Update documentation

**Files:**

- Modify: `docs/cheatsheet.md`

- [ ] **Step 1: Update the command-line keymap table**

Document both:

- `:` shows a guidance notification
- `<leader>:` opens the fine command line

- [ ] **Step 2: Update the quick notes**

Replace the note that says normal `:` is unchanged with the new behavior.

### Task 4: Verify the final state

**Files:**

- Test: `tests/colon_notify.lua`
- Test: `lua/config/keymaps.lua`
- Test: `docs/cheatsheet.md`

- [ ] **Step 1: Run the targeted headless test**

Run:

```bash
nvim --headless -u NONE -c "lua dofile('tests/colon_notify.lua')"
```

Expected: PASS.

- [ ] **Step 2: Run a headless config smoke check**

Run:

```bash
nvim --headless "+qa"
```

Expected: exits without Lua errors.

## Review Notes

This session is executing the plan inline instead of using the review-subagent workflow. The corresponding spec document is `docs/superpowers/specs/2026-04-04-block-default-colon-design.md`.

