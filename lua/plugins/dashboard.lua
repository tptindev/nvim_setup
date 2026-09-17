return {
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    config = function()
        local projects = require("config.projects")
        local recent = require("config.recent")

        -- dashboard's MRU list reads `v:oldfiles` straight from shada, so a file
        -- hidden through config/recent.lua would still turn up on the start
        -- screen, with no way to remove it there. Feed it the filtered list
        -- instead, and keep what was rendered so a line maps back to its path.
        local rendered_mru = {}

        require('dashboard.utils').get_mru_list = function()
            rendered_mru = recent.list()

            return rendered_mru
        end

        ---The recent file rendered on `line`. Longest match wins, so a path that
        ---happens to be the tail of a longer one does not claim the row.
        ---@param line string
        ---@return string|nil
        local function mru_path_at(line)
            local found = nil

            for _, path in ipairs(rendered_mru) do
                if line:find(path, 1, true) and (not found or #path > #found) then
                    found = path
                end
            end

            return found
        end

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

        local function footer()
            local tracked = #projects.list()

            local lines = {
                os.date('%d %B %Y | %H:%M'),
                tracked > 0 and (tracked .. ' project(s) tracked') or 'no projects tracked yet',
                '',
            }

            -- The centre column has already been rendered by the time the theme
            -- asks for a footer, so `rendered_mru` reflects what is on screen.
            if #rendered_mru > 0 then
                table.insert(lines, '<C-d> forgets the recent file under the cursor')
                table.insert(lines, '')
            end

            table.insert(lines, 'Lotus')

            return lines
        end

        local shortcuts = {
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
                -- Recent projects tracked by config/projects.lua,
                -- not a filesystem scan of a hardcoded drive.
                action = projects.pick,
            },
            {
                icon = ' ',
                desc = 'session',
                group = 'DashboardDesc',
                key = 'r',
                action = function()
                    if not projects.load_session() then
                        vim.notify('No session for ' .. projects.current(), vim.log.levels.WARN)
                    end
                end,
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
        }

        ---The shortcut row is one line holding every entry, so a click has to be
        ---resolved by column. Rebuild the byte spans `gen_shortcut` lays out:
        ---"  <icon><desc>[<key>]" per entry, two spaces between, centred.
        ---@param line string
        ---@param col integer  1-based byte column
        ---@return table|nil
        local function shortcut_at(line, col)
            local expected, start = '', line:find('[^%s]')

            for _, item in ipairs(shortcuts) do
                expected = expected .. '  ' .. (item.icon or '') .. item.desc
                if item.key then
                    expected = expected .. '[' .. item.key .. ']'
                end
            end

            if not start or vim.trim(line) ~= vim.trim(expected) then
                return nil
            end

            start = start - 1

            for _, item in ipairs(shortcuts) do
                local stop = start + #((item.icon or '') .. item.desc)
                if item.key then
                    stop = stop + vim.fn.strwidth(item.key) + 2
                end

                if col > start and col <= stop then
                    return item
                end

                start = stop + 2
            end

            return nil
        end

        ---Act on the dashboard row at `line`/`col`. Every actionable row is
        ---either a recent file or a shortcut. dashboard's own handler is not
        ---reused: it digs the path out of the raw line, and
        ---`math.min(text:find('%w'), text:find('%p'))` throws on a line with
        ---letters but no punctuation -- the footer, and "  empty files", which
        ---is what the list becomes once every recent file has been forgotten.
        ---@param line string
        ---@param col integer
        local function activate(line, col)
            local path = mru_path_at(line)
            if path then
                vim.cmd('edit ' .. vim.fn.fnameescape(path))
                return
            end

            local shortcut = shortcut_at(line, col)
            if not shortcut then
                return
            end

            if type(shortcut.action) == 'function' then
                shortcut.action()
            elseif type(shortcut.action) == 'string' then
                vim.cmd(shortcut.action)
            end
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

        -- The theme maps <CR> itself while rendering, which is after the
        -- FileType autocmd below has run, so take it over on DashboardLoaded --
        -- fired from a scheduled callback once the last row is on screen.
        vim.api.nvim_create_autocmd('User', {
            pattern = 'DashboardLoaded',
            callback = function()
                local buf = vim.api.nvim_get_current_buf()
                if vim.bo[buf].filetype ~= 'dashboard' then
                    return
                end

                vim.keymap.set('n', '<CR>', function()
                    local cursor = vim.api.nvim_win_get_cursor(0)
                    activate(vim.api.nvim_get_current_line(), cursor[2] + 1)
                end, {
                    buffer = buf,
                    nowait = true,
                    silent = true,
                    desc = 'Open the dashboard entry under the cursor',
                })
            end,
        })

        vim.api.nvim_create_autocmd('FileType', {
            pattern = 'dashboard',
            callback = function(event)
                local win_opts = { win = vim.api.nvim_get_current_win() }

                -- dashboard-nvim ships no mouse bindings at all: every entry is
                -- keyboard-only. Act on the row the click landed on, using its
                -- column so one shortcut in the row can be told from the next.
                local function activate_click()
                    local pos = vim.fn.getmousepos()
                    if pos.winid ~= vim.api.nvim_get_current_win() or pos.line <= 0 then
                        return
                    end

                    pcall(vim.api.nvim_win_set_cursor, pos.winid, { pos.line, 0 })

                    local line = vim.api.nvim_buf_get_lines(event.buf, pos.line - 1, pos.line, false)[1]
                    if line then
                        activate(line, pos.column)
                    end
                end

                for _, lhs in ipairs({ '<LeftRelease>', '<2-LeftMouse>' }) do
                    vim.keymap.set('n', lhs, activate_click, {
                        buffer = event.buf,
                        nowait = true,
                        silent = true,
                        desc = 'Activate the clicked dashboard entry',
                    })
                end

                -- Drop a recent file without leaving the start screen. The row
                -- is removed in place rather than re-rendering the dashboard,
                -- which would re-save the already-hidden statusline settings as
                -- if they were the user's. `<C-d>` and not `d`: the theme hands
                -- every letter of `letter_list` out as an entry hotkey.
                local function forget_recent()
                    local path = mru_path_at(vim.api.nvim_get_current_line())
                    if not path then
                        return
                    end

                    recent.forget(path)
                    vim.notify('Forgot recent file: ' .. vim.fn.fnamemodify(path, ':~'))

                    local lnum = vim.api.nvim_win_get_cursor(0)[1]

                    vim.bo[event.buf].modifiable = true
                    vim.api.nvim_buf_set_lines(event.buf, lnum - 1, lnum, false, {})
                    vim.bo[event.buf].modifiable = false
                    vim.bo[event.buf].modified = false
                end

                vim.keymap.set('n', '<C-d>', forget_recent, {
                    buffer = event.buf,
                    nowait = true,
                    silent = true,
                    desc = 'Forget the recent file on this line',
                })

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

        require('dashboard').setup({
            theme = 'hyper',
            shuffle_letter = false,
            config = {
                header = header,
                shortcut = shortcuts,
                packages = { enable = false },
                -- dashboard's own project list keeps a separate, crash-prone
                -- cache file; config/projects.lua owns this instead.
                project = { enable = false },
                mru = {
                    enable = true,
                },
                footer = footer,
            },
        })
    end,
    dependencies = { { 'nvim-tree/nvim-web-devicons' } },
}
