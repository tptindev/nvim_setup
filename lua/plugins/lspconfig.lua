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
            single_file_support = true,
            cmd = {
                "clangd",
                "--background-index",
                "--clang-tidy",
                "--completion-style=detailed",
                "--function-arg-placeholders=1",
            },
            root_markers = {
                "CMakePresets.json",
                "CMakeLists.txt",
                "compile_commands.json",
                "compile_flags.txt",
                ".clangd",
                ".clang-tidy",
                ".git",
            },
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

        vim.lsp.config("glsl_analyzer", {
            capabilities = capabilities,
        })

        -- mason-lspconfig v2 installs and auto-enables configured servers.
        mason_lspconfig.setup({
            ensure_installed = { "clangd", "lua_ls", "glsl_analyzer" },
            automatic_enable = {
                exclude = { "cmake" },
            },
        })
    end,
}
