return {
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    config = function()
        local uv = vim.uv or vim.loop
        local projects = require("config.projects")
        local header = {
            '',
            '',
            ' _      ___ _____ _   _ ____  ',
            '| |    / _ \\_   _| | | / ___| ',
            '| |   | | | || | | | | \\___ \\ ',
            '| |___| |_| || | | |_| |___) |',
            '|_____\\\\___/ |_|  \\___/|____/ ',
            '',
        }

        local function open_config()
            vim.cmd('FzfLua files cwd=' .. vim.fn.stdpath('config'))
        end

        local function collect_directories(root, directories)
            local handle = uv.fs_scandir(root)
            if not handle then
                return
            end

            while true do
                local name, kind = uv.fs_scandir_next(handle)
                if not name then
                    break
                end

                if kind == 'directory' and name ~= '.git' then
                    local path = vim.fs.joinpath(root, name)
                    table.insert(directories, path)
                    collect_directories(path, directories)
                end
            end
        end

        local function find_directories()
            local root = vim.fs.normalize('D:/')
            local stat = uv.fs_stat(root)
            if not stat or stat.type ~= 'directory' then
                return {}
            end

            local directories = { root }
            collect_directories(root, directories)

            table.sort(directories, function(a, b)
                return a:lower() < b:lower()
            end)

            return directories
        end

        local function open_project()
            local directories = find_directories()

            if vim.tbl_isempty(directories) then
                vim.notify('No folders found in D:/.', vim.log.levels.WARN)
                return
            end

            require('fzf-lua').fzf_exec(directories, {
                prompt = 'Folders> ',
                winopts = {
                    preview = { hidden = true },
                },
                actions = {
                    ['enter'] = function(selected)
                        local path = selected and selected[1]
                        if not path or vim.fn.isdirectory(path) == 0 then
                            return
                        end

                        projects.set_root(path)
                        vim.cmd('enew')
                        vim.schedule(function()
                            vim.cmd('Neotree close')
                            vim.cmd('Neotree dir=' .. vim.fn.fnameescape(path) .. ' left reveal_force_cwd')
                        end)
                    end,
                },
            })
        end

        local function footer()
            return {
                os.date('%d %B %Y | %H:%M'),
                '',
                'Lotus',
            }
        end

        local function get_project_cache()
            local cache_path = vim.fs.joinpath(vim.fn.stdpath('cache'), 'dashboard', 'cache')
            local stat = uv.fs_stat(cache_path)

            if not stat or stat.type ~= 'file' then
                return {}
            end

            local fd = uv.fs_open(cache_path, 'r', 438)
            if not fd then
                return {}
            end

            local data = uv.fs_read(fd, stat.size, 0)
            uv.fs_close(fd)

            if type(data) ~= 'string' or data == '' then
                return {}
            end

            data = data:gsub('%z', '')
            local ok_load, chunk = pcall(loadstring, data)
            if not ok_load or type(chunk) ~= 'function' then
                return {}
            end

            local ok_exec, projects = pcall(chunk)
            if not ok_exec or type(projects) ~= 'table' then
                return {}
            end

            return projects
        end

        local function reset_invalid_project_cache()
            local cache_dir = vim.fs.joinpath(vim.fn.stdpath('cache'), 'dashboard')
            local cache_path = vim.fs.joinpath(cache_dir, 'cache')
            local empty_projects = 'return {}'

            local function write_empty_projects()
                uv.fs_mkdir(cache_dir, 448)
                local new_fd = uv.fs_open(cache_path, 'w', 420)
                if not new_fd then
                    return
                end

                uv.fs_write(new_fd, empty_projects, 0)
                uv.fs_close(new_fd)
            end

            local stat = uv.fs_stat(cache_path)

            if not stat or stat.type ~= 'file' then
                write_empty_projects()
                return
            end

            local fd = uv.fs_open(cache_path, 'r', 438)
            if not fd then
                write_empty_projects()
                return
            end

            local data = uv.fs_read(fd, stat.size, 0)
            uv.fs_close(fd)

            if type(data) ~= 'string' or data == '' then
                write_empty_projects()
                return
            end

            data = data:gsub('%z', '')

            local ok_load, chunk = pcall(loadstring, data)
            local ok_exec = false

            if ok_load and type(chunk) == 'function' then
                local ok_result, result = pcall(chunk)
                ok_exec = ok_result and type(result) == 'table'
            end

            if ok_exec then
                return
            end

            uv.fs_unlink(cache_path)
            write_empty_projects()
        end

        local function apply_highlights()
            vim.api.nvim_set_hl(0, 'DashboardHeader', { fg = '#f7768e', bold = true })
            vim.api.nvim_set_hl(0, 'DashboardDesc', { fg = '#c0caf5' })
            vim.api.nvim_set_hl(0, 'DashboardKey', { fg = '#bb9af7', bold = true })
            vim.api.nvim_set_hl(0, 'DashboardIcon', { fg = '#e0af68' })
            vim.api.nvim_set_hl(0, 'DashboardFooter', { fg = '#7f849c', italic = true })
        end

        apply_highlights()

        vim.api.nvim_create_autocmd('ColorScheme', {
            callback = apply_highlights,
        })

        vim.api.nvim_create_autocmd('FileType', {
            pattern = 'dashboard',
            callback = function(event)
                local win_opts = { win = vim.api.nvim_get_current_win() }

                vim.api.nvim_set_option_value('spell', false, win_opts)
                vim.api.nvim_set_option_value('foldenable', false, win_opts)
                vim.api.nvim_set_option_value('foldmethod', 'manual', win_opts)
                vim.api.nvim_set_option_value('number', false, win_opts)
                vim.api.nvim_set_option_value('relativenumber', false, win_opts)
                vim.api.nvim_set_option_value('cursorline', false, win_opts)
                vim.api.nvim_set_option_value('cursorcolumn', false, win_opts)
                vim.api.nvim_set_option_value('signcolumn', 'no', win_opts)
            end,
        })

        reset_invalid_project_cache()
        local has_projects = #get_project_cache() > 0

        require('dashboard').setup({
            theme = 'hyper',
            shuffle_letter = false,
            config = {
                header = header,
                shortcut = {
                    {
                        icon = ' ',
                        desc = 'files',
                        group = 'DashboardDesc',
                        key = 'f',
                        action = 'FzfLua files',
                    },
                    {
                        icon = ' ',
                        desc = 'projects',
                        group = 'DashboardDesc',
                        key = 'p',
                        action = open_project,
                    },
                    {
                        icon = ' ',
                        desc = 'settings',
                        group = 'DashboardDesc',
                        key = 's',
                        action = open_config,
                    },
                    {
                        icon = ' ',
                        desc = 'exit',
                        group = 'DashboardDesc',
                        key = 'q',
                        action = 'qa',
                    },
                },
                packages = { enable = false },
                project = {
                    enable = has_projects,
                    limit = 6,
                    icon = ' ',
                    label = 'Recent Projects',
                    action = 'FzfLua files cwd=',
                },
                mru = {
                    enable = true,
                },
                footer = footer,
            },
        })
    end,
    dependencies = { { 'nvim-tree/nvim-web-devicons' } },
}
