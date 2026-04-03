return {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    opts = function()
        local buffers = require("config.buffers")

        return {
            options = {
                close_command = buffers.close,
                right_mouse_command = buffers.close,
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
        }
    end,
}
