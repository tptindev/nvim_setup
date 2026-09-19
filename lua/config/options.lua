local o = vim.o
local a = vim.api
vim.opt.fileformats = { "unix", "dos" }
vim.opt.fileformat = "unix"
-- Cursor visibility
o.cursorline = true
o.cursorlineopt = "screenline"
o.cursorcolumn = false
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
-- Code folding: Treesitter installs a foldexpr per filetype (see plugins/treesitter.lua).
-- `indent` is the fallback for everything else; a high foldlevel keeps files open.
o.foldmethod = "indent"
o.foldlevel = 99
o.foldlevelstart = 99
o.foldenable = true
-- Better indentation
o.autoindent = true
o.copyindent = true
o.breakindent = true
o.expandtab = true
-- Tab width
o.tabstop = 2
o.shiftwidth = 2
o.softtabstop = 2
-- Spell checking: prose only. Enabling it globally underlines half of every
-- C++ identifier.
o.spell = false
o.spelllang = "en_us"
a.nvim_create_autocmd("FileType", {
    group = a.nvim_create_augroup("ProseSpell", { clear = true }),
    pattern = { "markdown", "text", "gitcommit", "help" },
    callback = function()
        vim.opt_local.spell = true
    end,
})
-- System clipboard integration
o.clipboard = "unnamedplus"
-- Mouse: enabled in every mode, including the command line.
-- In a terminal this means Neovim captures the mouse, so use Shift+drag for the
-- terminal emulator's own selection. Neovide is unaffected.
o.mouse = "a"
-- Right click opens the context menu built in config/mouse.lua and moves the
-- cursor to what was clicked; Shift+click extends a selection.
o.mousemodel = "popup_setpos"
o.mousescroll = "ver:3,hor:6"
-- Needed for hover highlights (bufferline close buttons, dropbar, which-key)
o.mousemoveevent = true
-- Reserve the sign column so diagnostics/git signs do not shift the text
o.signcolumn = "yes"
-- Open splits where the eye expects them
o.splitright = true
o.splitbelow = true
-- Update time
o.updatetime = 500
-- Time out length
o.timeoutlen = 300
-- Built-in popup menu height. 0 = use the available space, which the mouse
-- context menu needs; blink.cmp draws its own completion window and is not
-- affected by this option.
o.pumheight = 0
-- Hide the command-line row when idle so transient messages do not linger under the statusline
o.cmdheight = 0
o.showmode = false
o.showcmd = false
-- Always show the top tabline for open buffers
o.showtabline = 2
-- Enable 24-bit colors so Treesitter/LSP highlights can use richer palettes
o.termguicolors = true
-- Nerd Font glyphs are assumed available (see lua/config/neovide.lua for the
-- GUI font); fzf-lua and mini.icons read this to pick glyph vs ascii icons.
vim.g.have_nerd_font = true

-- Neovide-only window/font/input settings and its zoom keymaps.
require("config.neovide").setup()

vim.filetype.add({
    extension = {
        glsl = "glsl",
        vert = "glsl",
        frag = "glsl",
        vs = "glsl",
        fs = "glsl",
        gs = "glsl",
        geom = "glsl",
        comp = "glsl",
        tesc = "glsl",
        tese = "glsl",
        rgen = "glsl",
        rchit = "glsl",
        rmiss = "glsl",
        rahit = "glsl",
        rint = "glsl",
        rcall = "glsl",
        mesh = "glsl",
        task = "glsl",
    },
})

local c_style_group = a.nvim_create_augroup("CStyleIndentation", { clear = true })
a.nvim_create_autocmd("FileType", {
    group = c_style_group,
    pattern = { "c", "cpp", "glsl", "cmake" },
    callback = function()
        vim.bo.tabstop = 2
        vim.bo.shiftwidth = 2
        vim.bo.softtabstop = 2
        vim.bo.expandtab = true

        if vim.bo.filetype == "glsl" then
            vim.bo.commentstring = "// %s"
        end
    end,
})

-- Lua and Python both format to 4 spaces (stylua's default indent, PEP 8), so
-- typing at the global 2-space width would be undone by the next save.
local four_space_group = a.nvim_create_augroup("FourSpaceIndentation", { clear = true })
a.nvim_create_autocmd("FileType", {
    group = four_space_group,
    pattern = { "lua", "python" },
    callback = function()
        vim.bo.tabstop = 4
        vim.bo.shiftwidth = 4
        vim.bo.softtabstop = 4
        vim.bo.expandtab = true
    end,
})

-- Yank indication
local highlight_group = a.nvim_create_augroup("YankHighlight", { clear = true })
a.nvim_create_autocmd("TextYankPost", {
    callback = function()
        -- vim.highlight was renamed to vim.hl in 0.11 and is deprecated.
        local hl = vim.hl or vim.highlight
        hl.on_yank()
    end,
    group = highlight_group,
    pattern = "*",
})
-- Disabling unused plugins
for _, plugin in pairs({
    "netrw",
    "netrwPlugin",
    "netrwSettings",
    "netrwFileHandlers",
    "2html_plugin",
    "spellfile_plugin",
    "matchit"
}) do
    vim.g["loaded_" .. plugin] = 1
end
