return {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    keys = {
        {
            "<leader>e",
            function()
                vim.cmd("Neotree toggle left reveal_force_cwd")
            end,
            desc = "Toggle Explorer",
        },
    },
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
    },
    opts = {
        close_if_last_window = false,
        enable_git_status = true,
        popup_border_style = "rounded",
        default_component_configs = {
            indent = {
                indent_size = 2,
                padding = 1,
            },
        },
        filesystem = {
            filtered_items = {
                hide_dotfiles = false,
                hide_gitignored = false,
            },
            follow_current_file = {
                enabled = true,
            },
            hijack_netrw_behavior = "open_current",
            use_libuv_file_watcher = true,
        },
        window = {
            position = "left",
            width = 32,
        },
    },
    config = function(_, opts)
        require("neo-tree").setup(opts)

        vim.api.nvim_create_autocmd("VimEnter", {
            callback = function()
                local current = vim.api.nvim_get_current_buf()
                local current_win = vim.api.nvim_get_current_win()
                local filetype = vim.bo[current].filetype
                local buftype = vim.bo[current].buftype
                local win_config = vim.api.nvim_win_get_config(current_win)

                if filetype == "dashboard" or filetype == "lazy" or buftype ~= "" then
                    return
                end

                if win_config.relative ~= "" then
                    return
                end

                vim.defer_fn(function()
                    if not vim.api.nvim_buf_is_valid(current) or not vim.api.nvim_win_is_valid(current_win) then
                        return
                    end

                    if vim.bo[current].filetype == "lazy" or vim.bo[current].buftype ~= "" then
                        return
                    end

                    vim.cmd("Neotree show left reveal_force_cwd")
                end, 20)
            end,
        })
    end,
}
