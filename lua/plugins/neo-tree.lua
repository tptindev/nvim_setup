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
                local filetype = vim.bo[current].filetype

                if filetype == "dashboard" then
                    return
                end

                vim.schedule(function()
                    vim.cmd("Neotree show left reveal_force_cwd")
                end)
            end,
        })
    end,
}
