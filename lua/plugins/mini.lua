return {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
        local hipatterns = require("mini.hipatterns")

        require("mini.icons").setup({
            style = vim.g.have_nerd_font == false and "ascii" or "glyph",
        })
        MiniIcons.mock_nvim_web_devicons()
        MiniIcons.tweak_lsp_kind("prepend")

        require("mini.move").setup()

        require("mini.notify").setup({
            lsp_progress = {
                enable = true,
                duration_last = 1500,
            },
            window = {
                winblend = 0,
            },
        })
        vim.notify = MiniNotify.make_notify()

        require("mini.pairs").setup()
        require("mini.surround").setup({
            mappings = {
                add = "sa",
                delete = "sd",
                find = "sf",
                find_left = "sF",
                highlight = "sh",
                replace = "sr",
                update_n_lines = "",
            },
        })

        -- mini.statusline intentionally NOT loaded — lualine.nvim handles the statusline

        hipatterns.setup({
            highlighters = {
                fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
                hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
                todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
                note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
                hex_color = hipatterns.gen_highlighter.hex_color(),
            },
        })
    end,
}
