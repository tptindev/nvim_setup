return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        "mason.nvim",
        "mason-lspconfig.nvim",
    },
    config = function()
        local lspconfig = require("lspconfig")
        local mason_lspconfig = require("mason-lspconfig")

        -- Setup mason-lspconfig to auto-install and configure LSP servers
        mason_lspconfig.setup({
            ensure_installed = { "clangd", "lua_ls" },
            automatic_installation = true,
        })

        -- Setup handlers for LSP servers
        mason_lspconfig.setup_handlers({
            function(server_name)
                lspconfig[server_name].setup({})
            end,
            ["clangd"] = function()
                lspconfig.clangd.setup({
                    capabilities = require("blink.cmp").get_lsp_capabilities(),
                })
            end,
            ["lua_ls"] = function()
                lspconfig.lua_ls.setup({
                    capabilities = require("blink.cmp").get_lsp_capabilities(),
                    settings = {
                        Lua = {
                            diagnostics = {
                                globals = { "vim" },
                            },
                        },
                    },
                })
            end,
        })
    end,
}
