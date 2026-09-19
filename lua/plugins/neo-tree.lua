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
            -- config/projects.lua turns any directory buffer into "open this
            -- project", so neo-tree must not claim them.
            hijack_netrw_behavior = "disabled",
            use_libuv_file_watcher = true,
        },
        window = {
            position = "left",
            width = 32,
            mappings = {
                ["<2-LeftMouse>"] = "open",
                -- Middle click opens in a split, like a browser opens a new tab.
                ["<MiddleMouse>"] = "open_split",
                -- <RightMouse> is deliberately left unmapped: 'mousemodel=popup_setpos'
                -- only opens the context menu when the key is free. It moves the
                -- cursor to the clicked node first, then config/mouse.lua builds
                -- the file-manager menu for it.
            },
        },
    },
    config = function(_, opts)
        -- A file buffer that still lands in the tree window is ejected by
        -- neo-tree itself (`setup/init.lua`, `buffer_enter_event`): it runs
        -- `b#`, deletes the buffer, then re-opens the file in a real window
        -- through `utils.open_file`. That path restores the tree width with
        -- `_compat.nvim_win_set_width`, which calls `vim.api.nvim_win_resize`
        -- as soon as `has("nvim-0.13")` is true -- and this build reports 0.13
        -- while the function does not exist yet (v0.13.0-dev-29), so the eject
        -- throws halfway and can leave the file deleted and never reopened.
        -- Both shims fail the same way, deterministically. `utils.lua` holds a
        -- reference to this same table, so replacing the fields is enough
        -- whatever order the modules are required in.
        if vim.api.nvim_win_resize == nil then
            local compat = require("neo-tree.utils._compat")
            compat.nvim_win_set_width = vim.api.nvim_win_set_width
            compat.nvim_win_set_height = vim.api.nvim_win_set_height
        end

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
