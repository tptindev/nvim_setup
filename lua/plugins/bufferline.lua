return {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    opts = {
        options = {
            mode = "buffers",
            always_show_bufferline = true,
            separator_style = "slant",
            diagnostics = false,
            offsets = {
                {
                    filetype = "neo-tree",
                    text = "Explorer",
                    highlight = "Directory",
                    text_align = "left",
                    separator = true,
                },
            },
            custom_filter = function(bufnr)
                local filetype = vim.bo[bufnr].filetype
                return filetype ~= "dashboard"
            end,
        },
    },
}
