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

        vim.diagnostic.config({
            virtual_text = {
                spacing = 2,
                source = "if_many",
            },
            signs = true,
            underline = true,
            update_in_insert = false,
            severity_sort = true,
            float = {
                border = "rounded",
                source = true,
            },
        })

        -- on_new_config is an lspconfig-era hook and is ignored by vim.lsp.config.
        -- cmake-tools copies compile_commands.json into the project root on Windows.
        vim.lsp.config("clangd", {
            capabilities = capabilities,
            single_file_support = true,
            workspace_required = false,
            cmd = {
                "clangd",
                "--background-index",
                "--clang-tidy",
                "--completion-style=detailed",
                "--function-arg-placeholders=1",
                "--header-insertion=iwyu",
                "--pch-storage=memory",
                "--query-driver=**",
            },
            filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
            root_markers = {
                ".clangd",
                ".clang-tidy",
                ".clang-format",
                "compile_commands.json",
                "compile_flags.txt",
                "CMakePresets.json",
                "CMakeLists.txt",
                ".git",
            },
            init_options = {
                fallbackFlags = { "-Wall", "-Wextra" },
            },
        })

        vim.lsp.config("lua_ls", {
            capabilities = capabilities,
            settings = {
                Lua = {
                    diagnostics = {
                        globals = { "vim" },
                    },
                    workspace = {
                        checkThirdParty = false,
                    },
                },
            },
        })

        vim.lsp.config("glsl_analyzer", {
            capabilities = capabilities,
            single_file_support = true,
            workspace_required = false,
            -- The filetype autocmds in config/options.lua map every shader
            -- extension onto `glsl`, so that is the only filetype in play.
            filetypes = { "glsl" },
            root_markers = { ".git", "CMakeLists.txt" },
        })

        -- neocmakelsp: completion/hover for CMakeLists.txt. Needs snippet
        -- support advertised, which blink.cmp's capabilities already provide.
        vim.lsp.config("neocmake", {
            capabilities = capabilities,
            single_file_support = true,
            workspace_required = false,
            root_markers = { "CMakePresets.json", "CMakeLists.txt", ".neocmake.toml", ".git" },
        })

        -- mason-lspconfig v2 installs and auto-enables configured servers.
        mason_lspconfig.setup({
            ensure_installed = { "clangd", "lua_ls", "glsl_analyzer", "neocmake" },
            automatic_enable = {
                -- `cmake` is the python cmake-language-server; we use neocmake.
                exclude = { "cmake" },
            },
        })
    end,
}
