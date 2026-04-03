return {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        require("kanagawa").setup({
            compile = false,
            transparent = false,
            terminalColors = true,
            theme = "wave",
            colors = {
                theme = {
                    all = {
                        ui = {
                            bg_gutter = "none",
                        },
                    },
                },
            },
        })

        vim.cmd.colorscheme("kanagawa")

        local semantic_links = {
            ["@lsp.type.class.cpp"] = "@type",
            ["@lsp.type.struct.cpp"] = "@type",
            ["@lsp.type.namespace.cpp"] = "@module",
            ["@lsp.type.parameter.cpp"] = "@variable.parameter",
            ["@lsp.type.property.cpp"] = "@property",
            ["@lsp.type.enumMember.cpp"] = "@constant",
            ["@lsp.mod.defaultLibrary.cpp"] = "@module.builtin",
        }

        local function apply_semantic_links()
            for from, to in pairs(semantic_links) do
                vim.api.nvim_set_hl(0, from, { link = to })
            end
        end

        apply_semantic_links()

        vim.api.nvim_create_autocmd("ColorScheme", {
            pattern = "*",
            callback = apply_semantic_links,
        })
    end,
}
