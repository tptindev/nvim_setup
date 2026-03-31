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

        require("mini.statusline").setup({
            use_icons = vim.g.have_nerd_font ~= false,
            content = {
                active = function()
                    local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
                    local git = MiniStatusline.section_git({ trunc_width = 40 })
                    local diagnostics = MiniStatusline.section_diagnostics({ trunc_width = 75 })
                    local filename = MiniStatusline.section_filename({ trunc_width = 140 })
                    local fileinfo = MiniStatusline.section_fileinfo({ trunc_width = 120 })
                    local location = MiniStatusline.section_location({ trunc_width = 75 })
                    local search = MiniStatusline.section_searchcount({ trunc_width = 75 })

                    return MiniStatusline.combine_groups({
                        { hl = mode_hl, strings = { mode } },
                        { hl = "MiniStatuslineDevinfo", strings = { git, diagnostics } },
                        "%<",
                        { hl = "MiniStatuslineFilename", strings = { filename } },
                        "%=",
                        { hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
                        { hl = mode_hl, strings = { search, location } },
                    })
                end,
            },
        })

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
