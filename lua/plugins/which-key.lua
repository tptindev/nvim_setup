return {
    "folke/which-key.nvim",
    event = "VimEnter",
    opts = {
        delay = 300,
        preset = "modern",
        triggers = {
            { "<leader>", mode = { "n", "v" } },
        },
        spec = {
            { "<leader>f", group = "Find" },
            { "<leader>g", group = "Git" },
            { "<leader>l", group = "LSP" },
            { "<leader>c", group = "CMake" },
            { "<leader>t", group = "Terminal" },
        },
    },
    keys = {
        {
            "<leader>?",
            function()
                require("which-key").show({ global = false })
            end,
            desc = "Buffer keymaps",
        },
    },
}
