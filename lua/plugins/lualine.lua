-- Reuse the counts gitsigns already computed for the buffer instead of letting
-- lualine shell out to `git diff` on its own. Gitsigns also counts hunks in an
-- unwritten buffer, so the statusline agrees with the signs in the gutter.
local function gitsigns_diff()
    local status = vim.b.gitsigns_status_dict
    if not status then
        return nil
    end

    return {
        added = status.added,
        modified = status.changed,
        removed = status.removed,
    }
end

local function lsp_clients_component()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if not clients or vim.tbl_isempty(clients) then
        return ""
    end

    local names = {}
    for _, client in ipairs(clients) do
        if client.name and client.name ~= "" then
            table.insert(names, client.name)
        end
    end

    if vim.tbl_isempty(names) then
        return ""
    end

    return "LSP " .. table.concat(names, ", ")
end

return {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    opts = function()
        return {
            options = {
                theme = "auto",
                component_separators = { left = "│", right = "│" },
                section_separators = { left = "", right = "" },
                disabled_filetypes = {
                    statusline = { "dashboard" },
                    winbar = {},
                },
                always_divide_middle = true,
                globalstatus = false,
            },
            sections = {
                lualine_a = { "mode" },
                lualine_b = { "branch", { "diff", source = gitsigns_diff } },
                lualine_c = {
                    {
                        "filename",
                        path = 1,
                        file_status = true,
                        newfile_status = true,
                    },
                },
                lualine_x = {
                    "diagnostics",
                    lsp_clients_component,
                },
                lualine_y = { "filetype" },
                lualine_z = { "progress", "location" },
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = {
                    {
                        "filename",
                        path = 1,
                    },
                },
                lualine_x = { "location" },
                lualine_y = {},
                lualine_z = {},
            },
        }
    end,
    config = function(_, opts)
        require("lualine").setup(opts)
    end,
}
