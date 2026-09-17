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
            { "<leader>b", group = "Buffer" },
            { "<leader>f", group = "Find" },
            { "<leader>fr", desc = "Recent files panel" },
            { "<leader>g", group = "Git" },
            { "<leader>l", group = "LSP" },
            { "<leader>la", desc = "Code action" },
            { "<leader>lf", desc = "Format buffer" },
            { "<leader>lh", desc = "Switch source/header" },
            { "<leader>ln", desc = "Toggle inlay hints" },
            { "<leader>c", group = "CMake" },
            { "<leader>p", group = "Project" },
            { "<leader>pm", desc = "Project panel" },
            { "<leader>u", group = "UI" },
            { "<leader>e", desc = "Toggle Explorer" },
            { "<leader>t", desc = "Toggle Terminal" },
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
