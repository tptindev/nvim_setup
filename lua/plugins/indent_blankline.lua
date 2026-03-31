return {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
        indent = {
            char = "│",
        },
        scope = {
            enabled = true,
        },
        exclude = {
            buftypes = {
                "nofile",
                "prompt",
                "quickfix",
                "terminal",
            },
            filetypes = {
                "checkhealth",
                "help",
                "lazy",
                "lspinfo",
                "mason",
            },
        },
    },
}
