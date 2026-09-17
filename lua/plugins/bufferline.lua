return {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    opts = function()
        local buffers = require("config.buffers")

        -- Windows a clicked tab must never load a buffer into.
        local not_an_editor = {
            ["neo-tree"] = true,
            ["dashboard"] = true,
            ["clickable-panel"] = true,
        }

        ---A window the file can be opened in: never a float, never the sidebar.
        ---@return integer|nil
        local function editor_window()
            local current = vim.api.nvim_get_current_win()
            if vim.api.nvim_win_get_config(current).relative == "" then
                return current
            end

            for _, win in ipairs(vim.api.nvim_list_wins()) do
                local buf = vim.api.nvim_win_get_buf(win)

                if
                    vim.api.nvim_win_get_config(win).relative == ""
                    and vim.bo[buf].buftype ~= "terminal"
                    and not not_an_editor[vim.bo[buf].filetype]
                then
                    return win
                end
            end
        end

        return {
            options = {
                close_command = buffers.close,
                -- A click on a tab must not land in a floating window. The
                -- default is `buffer %d`, which runs in the current window: with
                -- the toggleterm overlay focused, the file is loaded into the
                -- float, and toggleterm then loses its own window — is_open()
                -- checks that the window still shows its buffer, so the next
                -- toggle opens a second float and orphans the first, which can
                -- then only be closed with <C-w>q.
                left_mouse_command = function(bufnr)
                    local win = editor_window()
                    if not win then
                        return
                    end

                    vim.api.nvim_set_current_win(win)
                    vim.api.nvim_win_set_buf(win, bufnr)
                end,
                -- Middle click closes a tab, right click opens a small menu.
                middle_mouse_command = buffers.close,
                right_mouse_command = function(bufnr)
                    require("config.mouse").tab_menu(bufnr)
                end,
                hover = {
                    enabled = true,
                    delay = 120,
                    reveal = { "close" },
                },
                mode = "buffers",
                always_show_bufferline = true,
                separator_style = "slant",
                diagnostics = false,
                offsets = {
                    {
                        filetype = "neo-tree",
                        text = "Explorer",
                        highlight = "Directory",
                        text_align = "left",
                        separator = true,
                    },
                },
                custom_filter = function(bufnr)
                    local filetype = vim.bo[bufnr].filetype
                    return filetype ~= "dashboard"
                end,
            },
        }
    end,
}
