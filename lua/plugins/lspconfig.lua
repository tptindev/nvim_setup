return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        "mason.nvim",
        "mason-lspconfig.nvim",
    },
    config = function()
        local mason_lspconfig = require("mason-lspconfig")
        local capabilities = require("blink.cmp").get_lsp_capabilities()

        vim.lsp.config("clangd", {
            capabilities = capabilities,
        })

        vim.lsp.config("lua_ls", {
            capabilities = capabilities,
            settings = {
                Lua = {
                    diagnostics = {
                        globals = { "vim" },
                    },
                },
            },
        })

        -- mason-lspconfig v2 installs and auto-enables configured servers.
        mason_lspconfig.setup({
            ensure_installed = { "clangd", "lua_ls" },
            automatic_enable = true,
        })
    end,
}
