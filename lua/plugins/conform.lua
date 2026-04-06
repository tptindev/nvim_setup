return {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        formatters_by_ft = {
            lua = { "stylua" },
            c = { "clang-format" },
            cpp = { "clang-format" },
        },
        format_on_save = function(bufnr)
            local filetype = vim.bo[bufnr].filetype
            local supported = {
                lua = true,
                c = true,
                cpp = true,
            }

            if not supported[filetype] then
                return
            end

            return {
                timeout_ms = 2000,
                lsp_format = "fallback",
            }
        end,
    },
}
