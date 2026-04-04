# Lualine Statusline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `lualine.nvim` statusline with the approved `Focused IDE` layout for this Neovim config.

**Architecture:** Add a dedicated `lua/plugins/lualine.lua` plugin module and register it in the plugin list. Keep the lualine configuration self-contained, including a small helper that renders attached LSP client names only when they exist. Add a focused headless test that validates the returned layout and helper behavior without booting the full config.

**Tech Stack:** Lua, Neovim, lazy.nvim, headless Neovim test scripts

---

## File Structure

- Create: `lua/plugins/lualine.lua`
- Create: `tests/lualine_statusline.lua`
- Modify: `lua/plugins/init.lua`
- Modify: `docs/cheatsheet.md`
- Modify: `lazy-lock.json`

### Task 1: Add a failing statusline test

**Files:**

- Create: `tests/lualine_statusline.lua`

- [ ] **Step 1: Require the local `plugins.lualine` module**

Set `package.path` so the test can load the plugin module directly from the repo.

- [ ] **Step 2: Assert the `Focused IDE` sections are present**

Check that `opts()` returns `lualine_a` through `lualine_z` with the expected major components:

- mode
- branch and diff
- filename
- diagnostics
- filetype
- progress and location

- [ ] **Step 3: Assert inactive and disabled behavior is configured**

Verify the inactive sections are lightweight and `dashboard` is disabled.

- [ ] **Step 4: Assert the LSP helper collapses cleanly**

Stub `vim.lsp.get_clients` to return no clients, then one attached client, and verify the helper returns empty text or the client name as expected.

- [ ] **Step 5: Run the test and confirm it fails before implementation**

Run:

```bash
nvim --headless -u NONE -c "lua dofile('tests/lualine_statusline.lua')"
```

Expected: FAIL because `plugins.lualine` does not exist yet.

### Task 2: Implement the lualine plugin module

**Files:**

- Create: `lua/plugins/lualine.lua`
- Modify: `lua/plugins/init.lua`
- Modify: `lazy-lock.json`

- [ ] **Step 1: Add `nvim-lualine/lualine.nvim` as a plugin module**

Create a self-contained module that returns the plugin spec and config options.

- [ ] **Step 2: Build the approved `Focused IDE` layout**

Implement:

- `lualine_a`: mode
- `lualine_b`: branch and diff
- `lualine_c`: filename
- `lualine_x`: diagnostics and active LSP client
- `lualine_y`: filetype
- `lualine_z`: progress and location

- [ ] **Step 3: Add the LSP helper**

Return an empty string when no attached clients exist and a readable client-name list when they do.

- [ ] **Step 4: Configure inactive and disabled filetypes**

Fade inactive windows and disable the bar for `dashboard`.

- [ ] **Step 5: Register the plugin**

Add the module to `lua/plugins/init.lua` in a position that keeps UI plugins organized.

- [ ] **Step 6: Re-run the targeted test**

Run:

```bash
nvim --headless -u NONE -c "lua dofile('tests/lualine_statusline.lua')"
```

Expected: PASS.

### Task 3: Document the statusline

**Files:**

- Modify: `docs/cheatsheet.md`

- [ ] **Step 1: Add a short statusline section**

Document what the statusline shows so the cheatsheet reflects the new UI.

- [ ] **Step 2: Keep it focused**

Explain the layout briefly instead of listing every lualine option.

### Task 4: Verify the final state

**Files:**

- Test: `tests/lualine_statusline.lua`
- Test: `lua/plugins/lualine.lua`
- Test: `lua/plugins/init.lua`
- Test: `docs/cheatsheet.md`

- [ ] **Step 1: Run the targeted headless test**

Run:

```bash
nvim --headless -u NONE -c "lua dofile('tests/lualine_statusline.lua')"
```

Expected: PASS.

- [ ] **Step 2: Run a headless config smoke check**

Run:

```bash
nvim --headless "+qa"
```

Expected: exits without Lua errors.

## Review Notes

This session is executing the plan inline instead of using the plan-review subagent workflow. The corresponding spec document is `docs/superpowers/specs/2026-04-05-lualine-statusline-design.md`.
