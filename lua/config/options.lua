local o = vim.o
local a = vim.api
-- Cursor visibility
o.cursorline = true
o.cursorlineopt = "screenline"
o.cursorcolumn = true
-- Dynamic line numbers
o.number = true
a.nvim_create_autocmd(
    { "BufEnter", "FocusGained", "InsertLeave", "WinEnter" },
    { pattern = "*", command = "if &nu && mode() != 'i' | set rnu | endif", }
)
a.nvim_create_autocmd(
    { "BufLeave", "FocusLost", "InsertEnter", "WinLeave" },
    { pattern = "*", command = "if &nu | set nornu | endif", }
)
-- No line wrapping
o.wrap = false
-- Scroll offsetting
o.scrolloff = 3
-- Persistent undo
o.undofile = true
-- Disable backups
o.backup = false
o.writebackup = false
-- Improved search 
o.ignorecase = true
o.smartcase = true
o.hlsearch = false
-- Substitution preview
o.inccommand = "split"
-- Code folding 
o.foldmethod = "indent"
o.foldlevel = 4 
-- Better indentation
o.autoindent = true
o.copyindent = true
o.breakindent = true
-- Tab width
o.tabstop = 4
o.shiftwidth = 4
-- Spell checking
o.spell = true
o.spelllang = "en_us"
-- System clipboard integration
o.clipboard = "unnamedplus"
-- Update time
o.updatetime = 500
-- Time out length
o.timeoutlen = 300
-- Popup menu height
o.pumheight = 5
-- GUI font for Neovide
if vim.g.neovide then
    o.guifont = "JetBrainsMono Nerd Font:h12"
end
-- Yank indication
local highlight_group = a.nvim_create_augroup("YankHighlight", { clear = true })
a.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.highlight.on_yank()
    end,
    group = highlight_group,
    pattern = "*",
})
-- Disabling unused plugins 
for _, plugin in pairs({
    "netrwFileHandlers",
    "2html_plugin",
    "spellfile_plugin",
    "matchit"
}) do
    vim.g["loaded_" .. plugin] = 1
end

