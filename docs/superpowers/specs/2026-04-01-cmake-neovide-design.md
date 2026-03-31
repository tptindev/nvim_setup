# CMake Support In Neovide Design

**Date:** 2026-04-01

## Goal

Enable this Neovim/Neovide configuration to work smoothly with CMake-based C/C++ projects by covering both language-server support and day-to-day configure/build/run workflows.

## Current Context

The current config already uses:

- `neovim/nvim-lspconfig` in `lua/plugins/lspconfig.lua`
- `mason.nvim` and `mason-lspconfig.nvim` for LSP installation
- centralized keymaps in `lua/config/keymaps.lua`
- plugin registration through `lua/plugins/init.lua`

The repo currently installs and enables `clangd`, but it does not provide a CMake workflow layer for configure/build/run, nor explicit ergonomics around CMake project roots, targets, and presets.

## Recommended Approach

Add a dedicated CMake plugin configuration using `Civitasv/cmake-tools.nvim`, keep `clangd` as the C/C++ language server, and wire the two together through a consistent workflow:

- `cmake-tools.nvim` handles CMake project detection, configure, build, run, target selection, generator selection, and preset-aware commands
- `clangd` continues to provide completion, navigation, and diagnostics
- the workflow relies on CMake generating `compile_commands.json`, which `clangd` uses for accurate project-aware analysis

This keeps responsibilities clean and matches the current config style where plugins are declared in `lua/plugins/` and interactions live in `lua/config/keymaps.lua`.

## Alternatives Considered

### 1. Minimal `clangd`-only setup

Keep the current `clangd` setup and rely on manually running `cmake -S . -B build` outside Neovim.

Trade-off: the language server can work once `compile_commands.json` exists, but the editor still lacks an integrated configure/build/run workflow.

### 2. Manual keymaps around shell commands

Create custom keymaps that call `cmake` and `cmake --build` directly.

Trade-off: simple at first, but it becomes harder to support presets, target selection, generator switching, and per-project state, especially on Windows where `Ninja` and `MSVC` may both be used.

### 3. Recommended: dedicated CMake workflow plugin + `clangd`

Use `cmake-tools.nvim` for project workflow and preserve `clangd` for code intelligence.

Trade-off: adds one plugin and a few keymaps, but gives a cleaner daily workflow and better support for mixed `Ninja`/`MSVC` usage.

## Architecture

### Plugin registration

Add a new plugin spec file `lua/plugins/cmake.lua` and register it from `lua/plugins/init.lua`.

### CMake workflow plugin

Configure `cmake-tools.nvim` with a conservative Windows-friendly setup:

- recognize CMake projects via `CMakeLists.txt`
- prefer `CMakePresets.json` when present
- support generator and target selection when presets are absent
- keep build artifacts in a dedicated build directory
- expose configure, build, run, debug, and target-selection commands

### LSP integration

Keep `clangd` in `lua/plugins/lspconfig.lua`, but tune its configuration so it cooperates better with CMake-generated compile databases. The editor experience should become fully accurate after the project has been configured at least once.

### Keymaps

Add a small CMake keymap set to `lua/config/keymaps.lua`, for example:

- `<leader>cc` configure
- `<leader>cb` build
- `<leader>cr` run
- `<leader>ct` select target
- `<leader>cs` select launch target
- `<leader>cp` select configure preset or kit

The final mappings should avoid conflicts with existing bindings and remain easy to remember.

## Behavior Details

- Opening a folder containing `CMakeLists.txt` should allow the user to work from Neovide without dropping to an external shell for common project actions.
- If the project contains `CMakePresets.json`, the workflow should prefer presets.
- If no presets are present, the user should still be able to configure the project by selecting a generator or kit.
- `clangd` should provide reliable C/C++ navigation and diagnostics after CMake configure has generated the compile database.
- The first configure step remains necessary for fresh projects, because `clangd` depends on generated compile commands for accurate indexing.

## Error Handling

- If a directory is not a CMake project, the new keymaps should fail in the plugin's normal way without affecting unrelated editing.
- If the required toolchain is missing from the environment, configure/build may fail, but this should surface as a normal CMake/toolchain error rather than a Neovim config failure.
- The config should avoid forcing a single generator globally so projects can continue to use either `Ninja` or `MSVC`.

## Testing Plan

After implementation:

1. Start Neovim headlessly and confirm the config loads without Lua errors.
2. Open a sample CMake project in Neovide/Neovim.
3. Run configure from inside Neovim and confirm the build directory is created.
4. Run build and confirm the command completes successfully for a valid project.
5. Confirm that `clangd` attaches to a C/C++ file in the configured project and that navigation/diagnostics behave normally.

## Scope Boundaries

Included in this change:

- add a CMake workflow plugin
- register the plugin in the existing plugin list
- add editor keymaps for common CMake actions
- tune `clangd` for better CMake project support

Not included in this change:

- project-specific `CMakePresets.json` authoring
- automatic installation of external build tools like CMake, Ninja, or MSVC
- per-project custom task orchestration beyond the shared CMake workflow
