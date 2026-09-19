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

        ---Windows that have to keep the buffer they already hold, even when the
        ---click came from one of them. The dashboard is deliberately not in
        ---here: it is the placeholder sitting in the editor area, and replacing
        ---it with the file is exactly what a tab click should do.
        ---@param win integer
        ---@return boolean
        local function holds_its_buffer(win)
            local buf = vim.api.nvim_win_get_buf(win)
            return vim.bo[buf].filetype == "neo-tree" or vim.bo[buf].buftype == "terminal"
        end

        ---A window the file can be opened in: never a float, never the sidebar.
        ---The current window used to be taken as-is whenever it was not a float,
        ---which loaded the file straight into neo-tree whenever the sidebar had
        ---focus. neo-tree does eject it again from its own `BufEnter` handler,
        ---but that is a visible round trip through a code path this config
        ---should not be leaning on.
        ---@return integer|nil
        local function editor_window()
            local current = vim.api.nvim_get_current_win()
            if vim.api.nvim_win_get_config(current).relative == "" and not holds_its_buffer(current) then
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
                        -- Only the sidebar and floats are open. Make a window
                        -- for the file instead of dropping the click.
                        vim.cmd("botright vsplit")
                        win = vim.api.nvim_get_current_win()
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
