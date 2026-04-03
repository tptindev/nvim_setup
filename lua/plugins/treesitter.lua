return {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local languages = {
            "json",
            "lua",
            "query",
            "vim",
            "vimdoc",
            "c",
            "cpp",
            "cmake",
            "glsl",
        }

        require("nvim-treesitter").setup()
        require("nvim-treesitter").install(languages)

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "*",
            callback = function(args)
                pcall(vim.treesitter.start, args.buf)
            end,
        })
    end,
}
