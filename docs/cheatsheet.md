# Neovim Cheatsheet

Quick note for this config:

- `mapleader = <Space>`
- `maplocalleader = \`

## Core Default Keymaps

These are common built-in Vim/Neovim motions and actions worth remembering.

### Normal Mode

| Key | Action |
| --- | --- |
| `h` `j` `k` `l` | Move left/down/up/right |
| `w` / `b` / `e` | Move by word |
| `0` / `^` / `$` | Start / first non-blank / end of line |
| `gg` / `G` | Top / bottom of file |
| `%` | Jump between matching pairs |
| `fx` / `tx` | Find character `x` on current line |
| `;` / `,` | Repeat last `f`/`t` search forward/backward |
| `i` / `a` | Insert before / after cursor |
| `I` / `A` | Insert at line start / line end |
| `o` / `O` | New line below / above and enter insert mode |
| `dd` / `yy` | Delete line / yank line |
| `p` / `P` | Paste after / before cursor |
| `u` / `<C-r>` | Undo / redo |
| `x` / `X` | Delete char under / before cursor |
| `.` | Repeat last change |
| `/pattern` / `?pattern` | Search forward / backward |
| `n` / `N` | Next / previous search result |
| `*` / `#` | Search word under cursor forward / backward |
| `v` / `V` / `<C-v>` | Visual / linewise visual / block visual |
| `ciw` | Change inner word |
| `di(` | Delete inside parentheses |
| `yi"` | Yank inside quotes |
| `:w` / `:q` / `:wq` | Save / quit / save and quit |
| `:nohlsearch` | Clear search highlight |

### Window And Tab Management

| Key | Action |
| --- | --- |
| `<C-w>h` `j` `k` `l` | Move between windows |
| `<C-w>s` / `<C-w>v` | Split horizontally / vertically |
| `<C-w>c` / `<C-w>o` | Close current window / keep only current |
| `:tabnew` | Open a new tab |
| `gt` / `gT` | Next / previous tab |

### Insert Mode

| Key | Action |
| --- | --- |
| `<Esc>` | Back to normal mode |
| `<C-w>` | Delete previous word |
| `<C-u>` | Delete to start of line |
| `<C-h>` | Delete previous character |

## Custom Keymaps In This Config

Source: `lua/config/keymaps.lua`

### Movement And Editing

| Mode | Key | Action | Note |
| --- | --- | --- | --- |
| `n,v` | `<Up>` | Move up by screen line | Uses `gk` |
| `n,v` | `<Down>` | Move down by screen line | Uses `gj` |
| `i` | `<Up>` | Move up by screen line | Uses `<C-o>gk` |
| `i` | `<Down>` | Move down by screen line | Uses `<C-o>gj` |
| `n` | `O` | Add empty line above without staying in insert mode | Overrides default `O` behavior |
| `n` | `o` | Add empty line below without staying in insert mode | Overrides default `o` behavior |
| `n,v` | `x` | Delete without yanking to default register | Uses black-hole register |
| `n,v` | `X` | Delete backward without yanking to default register | Uses black-hole register |

### LSP

Only useful when an LSP server is attached to the current buffer.

| Mode | Key | Action |
| --- | --- | --- |
| `n` | `K` | Hover documentation |
| `n` | `<leader>rn` | Rename symbol |
| `n` | `<leader>ld` | FZF LSP definitions |
| `n` | `<leader>lr` | FZF LSP references |
| `n` | `<leader>li` | FZF LSP implementations |
| `n` | `<leader>lt` | FZF LSP typedefs |
| `n` | `<leader>ls` | FZF document symbols |
| `n` | `<leader>lS` | FZF workspace symbols |
| `n` | `<leader>lx` | FZF document diagnostics |
| `n` | `<leader>lq` | FZF quickfix list |

### FZF

| Mode | Key | Action |
| --- | --- | --- |
| `n` | `<leader>ff` | Find files |
| `n` | `<leader>fg` | Live grep |
| `n` | `<leader>fw` | Grep current word |
| `n` | `<leader>fb` | Find buffers |
| `n` | `<leader>fo` | Find old files |
| `n` | `<leader>fh` | Search help tags |

### Git

| Mode | Key | Action |
| --- | --- | --- |
| `n` | `<leader>gf` | Git files |
| `n` | `<leader>gs` | Git status |
| `n` | `<leader>gc` | Git commits |
| `n` | `<leader>gb` | Git branches |
| `n` | `<leader>gh` | Git file history |

### CMake

These mappings call `cmake-tools.nvim` commands and will only work when those commands are available.

| Mode | Key | Action |
| --- | --- | --- |
| `n` | `<leader>cc` | CMake configure |
| `n` | `<leader>cb` | CMake build |
| `n` | `<leader>cr` | CMake run |
| `n` | `<leader>ct` | Select CMake build target |
| `n` | `<leader>cs` | Select CMake launch target |
| `n` | `<leader>cp` | Select CMake preset or fallback kit |

### Dropbar

| Mode | Key | Action |
| --- | --- | --- |
| `n` | `<leader>;` | Pick symbols in winbar |
| `n` | `[;` | Go to start of current context |
| `n` | `];` | Select next context |

### Mini Surround

| Mode | Key | Action |
| --- | --- | --- |
| `n` | `sn` | Update surround search lines |

## Plugin Default Keymaps Worth Knowing

These are not manually mapped in `lua/config/keymaps.lua`, but they come from plugin setup.

### blink.cmp

Configured with `preset = "super-tab"`.

| Mode | Key | Action |
| --- | --- | --- |
| `i` | `<Tab>` | Accept or move through completion/snippet flow |
| `i` | `<S-Tab>` | Move backward through completion/snippet flow |
| `i` | `<CR>` | Confirm selected completion item |

Note: exact behavior depends on completion visibility and snippet state.

### mini.surround

Configured in `lua/plugins/mini.lua`.

| Mode | Key | Action |
| --- | --- | --- |
| `n,v` | `sa` | Add surrounding |
| `n` | `sd` | Delete surrounding |
| `n` | `sf` | Find right surrounding |
| `n` | `sF` | Find left surrounding |
| `n` | `sh` | Highlight surrounding |
| `n` | `sr` | Replace surrounding |

## Quick Notes

- `K` and `<leader>rn` depend on LSP being attached to the current buffer.
- `o` and `O` were remapped, so they no longer leave you in insert mode.
- `x` and `X` were remapped to the black-hole register, so they do not overwrite your default yank register.
- FZF mappings call `fzf-lua`.
- CMake mappings depend on `cmake-tools.nvim` commands being available.
