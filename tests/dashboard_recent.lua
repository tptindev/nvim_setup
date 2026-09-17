-- The start screen must show the same recent files as the panel, must be able
-- to drop one, and must not blow up on a row that carries no path: dashboard's
-- own confirm handler parses the line it lands on and throws when there is no
-- punctuation in it, which is exactly what "  empty files" looks like.
local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(("%s\nexpected: %s\nactual: %s"):format(message, vim.inspect(expected), vim.inspect(actual)))
    end
end

local function assert_truthy(value, message)
    if not value then
        error(message)
    end
end

local script_path = vim.fs.normalize(debug.getinfo(1, "S").source:sub(2))
local config_root = vim.fs.dirname(vim.fs.dirname(script_path))

package.path = table.concat({
    vim.fs.joinpath(config_root, "lua", "?.lua"),
    vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
    package.path,
}, ";")

local sandbox = vim.fn.tempname()
vim.fn.mkdir(sandbox, "p")
vim.g.recent_data_dir = sandbox
vim.g.projects_data_dir = sandbox

-- Stand-ins for the plugin: the spec only needs `setup` and the `utils` table
-- whose `get_mru_list` it replaces.
local stub_utils = {
    get_mru_list = function()
        error("dashboard's own MRU list should have been replaced")
    end,
}

local dashboard_opts = nil

package.preload["dashboard"] = function()
    return {
        setup = function(opts)
            dashboard_opts = opts
        end,
    }
end

package.preload["dashboard.utils"] = function()
    return stub_utils
end

local recent = require("config.recent")
recent.setup()

local files = {}
for i = 1, 3 do
    local path = vim.fs.normalize(sandbox .. "/file" .. i .. ".txt")
    vim.fn.writefile({ "x" }, path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    table.insert(files, path)
end

local spec = require("plugins.dashboard")
assert_equal(spec[1], "nvimdev/dashboard-nvim", "expected the dashboard spec to target nvimdev/dashboard-nvim")
spec.config()

assert_truthy(
    vim.deep_equal(stub_utils.get_mru_list(), recent.list()),
    "expected dashboard's MRU list to be config.recent's filtered list"
)

-- A file hidden through the panel must not come back on the start screen.
recent.forget(files[1])
assert_truthy(
    not vim.tbl_contains(stub_utils.get_mru_list(), files[1]),
    "expected a forgotten file to be gone from dashboard's MRU list"
)

---A scratch buffer standing in for a rendered dashboard.
---@param lines string[]
---@return integer
local function dashboard_buffer(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, buf)
    vim.bo[buf].filetype = "dashboard" -- fires the FileType autocmd the spec registers
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- The theme maps <CR> while rendering, so the spec waits for this.
    vim.api.nvim_exec_autocmds("User", { pattern = "DashboardLoaded", modeline = false })

    return buf
end

local function press(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

-- <C-d> drops the row under the cursor. `d` is unusable here: the theme hands
-- every letter of `letter_list` out as an entry hotkey.
local remaining = stub_utils.get_mru_list()
assert_truthy(#remaining > 1, "expected more than one recent file left")

local buf = dashboard_buffer({ "   " .. remaining[1] .. "   ", "footer" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
press("<C-d>")

assert_equal(#vim.api.nvim_buf_get_lines(buf, 0, -1, false), 1, "expected <C-d> to remove the row it was pressed on")
assert_equal(vim.bo[buf].modifiable, false, "expected the dashboard buffer to stay unmodifiable")
assert_truthy(
    not vim.tbl_contains(recent.list(), remaining[1]),
    "expected <C-d> to forget the file the row pointed at"
)

-- <CR> opens the file its row points at.
local target = recent.list()[1]
dashboard_buffer({ "   " .. target .. "   " })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
press("<CR>")

assert_equal(
    vim.fs.normalize(vim.api.nvim_buf_get_name(0)),
    target,
    "expected <CR> on a recent-file row to open that file"
)

-- A row with letters but no punctuation must be inert, not an error.
dashboard_buffer({ "   empty files", "Lotus" })
for lnum = 1, 2 do
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    local ok, err = pcall(press, "<CR>")
    assert_truthy(ok, "expected <CR> on a pathless row to do nothing, got: " .. tostring(err))
    assert_equal(vim.bo.filetype, "dashboard", "expected <CR> on a pathless row to stay on the dashboard")
end

-- The shortcut row is a single line, so it is resolved by column.
local shortcut_row = ""
for _, item in ipairs(dashboard_opts.config.shortcut) do
    shortcut_row = shortcut_row .. "  " .. item.icon .. item.desc .. "[" .. item.key .. "]"
end

local fired = nil
for _, item in ipairs(dashboard_opts.config.shortcut) do
    item.action = function()
        fired = item.desc
    end
end

dashboard_buffer({ shortcut_row })
vim.api.nvim_win_set_cursor(0, { 1, shortcut_row:find("session", 1, true) - 1 })
press("<CR>")
assert_equal(fired, "session", "expected <CR> to run the shortcut under the cursor")

fired = nil
vim.api.nvim_win_set_cursor(0, { 1, 0 })
press("<CR>")
assert_equal(fired, nil, "expected <CR> in the shortcut row's leading blank to do nothing")

vim.cmd("qa!")
