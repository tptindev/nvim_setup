local o = vim.o
local a = vim.api
vim.opt.fileformats = { "unix", "dos" }
vim.opt.fileformat = "unix"
-- Cursor visibility
o.cursorline = true
o.cursorlineopt = "screenline"
o.cursorcolumn = true
-- Dynamic line numbers
o.number = true
local number_toggle_group = a.nvim_create_augroup("DynamicLineNumbers", { clear = true })

local function should_show_line_numbers()
    return vim.bo.buftype == "" and vim.bo.filetype ~= "dashboard"
end

a.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
    group = number_toggle_group,
    pattern = "*",
    callback = function()
        if not should_show_line_numbers() then
            return
        end

        vim.wo.number = true
        vim.wo.relativenumber = vim.fn.mode() ~= "i"
    end,
})

a.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter", "WinLeave" }, {
    group = number_toggle_group,
    pattern = "*",
    callback = function()
        if not should_show_line_numbers() then
            return
        end

        vim.wo.relativenumber = false
    end,
})
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
o.expandtab = true
-- Tab width
o.tabstop = 2
o.shiftwidth = 2
o.softtabstop = 2
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
-- Hide the command-line row when idle so transient messages do not linger under the statusline
o.cmdheight = 0
o.showmode = false
o.showcmd = false
-- Always show the top tabline for open buffers
o.showtabline = 2
-- Enable 24-bit colors so Treesitter/LSP highlights can use richer palettes
o.termguicolors = true
-- GUI font for Neovide
if vim.g.neovide then
    o.guifont = "JetBrainsMono Nerd Font:h12"
end

vim.filetype.add({
    extension = {
        glsl = "glsl",
        vert = "glsl",
        frag = "glsl",
        vs = "glsl",
        fs = "glsl",
        geom = "glsl",
        comp = "glsl",
        tesc = "glsl",
        tese = "glsl",
    },
})

local c_style_group = a.nvim_create_augroup("CStyleIndentation", { clear = true })
a.nvim_create_autocmd("FileType", {
    group = c_style_group,
    pattern = { "c", "cpp" },
    callback = function()
        vim.bo.tabstop = 2
        vim.bo.shiftwidth = 2
        vim.bo.softtabstop = 2
        vim.bo.expandtab = true
    end,
})

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
