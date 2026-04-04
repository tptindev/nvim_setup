# Block Default Colon Command Line Design

**Date:** 2026-04-04

## Goal

Stop normal-mode `:` from opening Neovim's default command line and guide the user toward `<leader>:` instead.

## Current Context

This config already exposes `fine-cmdline.nvim` on `<leader>:` and keeps most user keymaps in `lua/config/keymaps.lua`.

Relevant existing files:

- `lua/plugins/fine_cmdline.lua` registers `<leader>:` for `fine-cmdline.nvim`
- `lua/config/keymaps.lua` contains normal-mode mappings and command-line abbreviations
- `docs/cheatsheet.md` documents the current command-line behavior

## Recommended Approach

Add a small normal-mode mapping for `:` in `lua/config/keymaps.lua` that shows an informational notification telling the user to use `<leader>:` for the fine command line.

This keeps the behavior local to the existing keymap file, preserves `<leader>:`, and avoids changing plugin setup for a simple interaction change.

## Alternatives Considered

### 1. Disable `:` with `<Nop>`

This is the smallest implementation, but it gives no feedback and makes the key feel broken.

### 2. Recommended: map `:` to an informational notification

This blocks the built-in command line while teaching the new workflow in-context.

### 3. Remap `:` directly to `fine-cmdline.nvim`

This would be convenient, but it changes the core key too aggressively and removes the deliberate distinction between default command-line entry and the custom entrypoint.

## Architecture

### Keymap behavior

- Add a helper function in `lua/config/keymaps.lua` that calls `vim.notify("Use <leader>: for fine command line", vim.log.levels.INFO)`
- Map normal-mode `:` to that helper
- Leave command-line mode and `<leader>:` behavior unchanged

### Documentation

- Update `docs/cheatsheet.md` to describe that `:` is blocked in normal mode and now shows a guidance notification
- Update the quick notes so they no longer say normal `:` is unchanged

## Error Handling

- The notification should be safe even if no external notification plugin is active because it uses built-in `vim.notify`
- The mapping only affects normal mode, so command-line abbreviations and command execution still work once the user opens the fine command line

## Testing Plan

1. Add a headless Lua test that loads `config.keymaps`
2. Verify the normal-mode `:` mapping exists and exposes a callback
3. Invoke the callback and assert the notification text and log level
4. Run a headless Neovim syntax/config smoke check

## Scope Boundaries

Included in this change:

- blocking normal-mode `:`
- showing a notification that points to `<leader>:`
- updating documentation
- adding a targeted test

Not included in this change:

- changing command-line mode behavior
- remapping `:` in visual, operator-pending, or insert mode
- altering `fine-cmdline.nvim` itself
