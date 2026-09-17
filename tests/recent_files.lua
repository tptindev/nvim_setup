local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(("%s\nexpected: %s\nactual: %s"):format(message, vim.inspect(expected), vim.inspect(actual)))
    end
end

local function assert_true(value, message)
    if not value then
        error(message)
    end
end

local script_path = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p"))
local config_root = vim.fs.dirname(vim.fs.dirname(script_path))

package.path = table.concat({
    vim.fs.joinpath(config_root, "lua", "?.lua"),
    vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
    package.path,
}, ";")

local sandbox = vim.fs.normalize(vim.fn.tempname())
vim.g.recent_data_dir = sandbox
vim.fn.mkdir(sandbox, "p")

local recent = require("config.recent")

-- Three real files plus one that does not exist.
local files = {}
for _, name in ipairs({ "one.cpp", "two.lua", "three.frag" }) do
    local path = vim.fs.joinpath(sandbox, name)
    vim.fn.writefile({ "// " .. name }, path)
    table.insert(files, vim.fs.normalize(path))
end

local missing = vim.fs.normalize(vim.fs.joinpath(sandbox, "gone.txt"))

vim.v.oldfiles = { files[1], missing, files[2], files[2], files[3] }

-- Unreadable and duplicate entries are dropped, order is preserved.
local listed = recent.list()
assert_equal(#listed, 3, "the list should keep three readable, unique files")
assert_equal(listed[1], files[1], "order should follow v:oldfiles")
assert_equal(listed[2], files[2], "duplicates should collapse to the first occurrence")
assert_equal(listed[3], files[3], "the third file should survive")

-- Forgetting hides a file and does not delete it.
recent.forget(files[2])
listed = recent.list()
assert_equal(#listed, 2, "forgetting should hide one file")
assert_true(not vim.tbl_contains(listed, files[2]), "the forgotten file should be gone from the list")
assert_true(vim.uv.fs_stat(files[2]) ~= nil, "forgetting must never delete the file")

-- The exclusion is persisted, so a fresh read still hides it.
package.loaded["config.recent"] = nil
local reloaded = require("config.recent")
vim.v.oldfiles = { files[1], files[2], files[3] }
assert_true(not vim.tbl_contains(reloaded.list(), files[2]), "the exclusion should persist across a reload")

-- Opening the file again earns its place back.
reloaded.remember(files[2])
assert_true(vim.tbl_contains(reloaded.list(), files[2]), "remember() should un-hide the file")

-- setup() wires that to BufReadPost.
reloaded.forget(files[2])
assert_true(not vim.tbl_contains(reloaded.list(), files[2]), "the file should be hidden again")

vim.cmd("set noswapfile")
reloaded.setup()
vim.cmd("edit " .. vim.fn.fnameescape(files[2]))
assert_true(vim.tbl_contains(reloaded.list(), files[2]), "opening a hidden file should un-hide it")

for _, name in ipairs({ "RecentFiles", "RecentForget", "RecentClear", "RecentReset" }) do
    assert_true(vim.fn.exists(":" .. name) == 2, name .. " should be defined by setup()")
end

-- A file opened this session appears even though v:oldfiles never grows.
vim.v.oldfiles = {}
vim.cmd("edit " .. vim.fn.fnameescape(files[3]))
assert_true(vim.tbl_contains(reloaded.list(), files[3]), "a file opened this session should be listed")
assert_equal(reloaded.list()[1], files[3], "the most recently opened file should come first")

-- clear() hides everything, reset() brings it all back.
vim.v.oldfiles = { files[1], files[2], files[3] }
reloaded.clear()
vim.v.oldfiles = { files[1], files[2], files[3] }
assert_equal(#reloaded.list(), 0, "clear() should hide every listed file")

reloaded.reset()
assert_equal(#reloaded.list(), 3, "reset() should restore the whole history")

-- The panel renders and is tagged for the right-click menu.
vim.o.columns = 120
vim.o.lines = 40
reloaded.panel()

local win = vim.api.nvim_get_current_win()
local buf = vim.api.nvim_win_get_buf(win)

assert_true(vim.api.nvim_win_get_config(win).relative ~= "", "the panel should be a floating window")
assert_equal(vim.b[buf].panel_kind, "recent", "the panel should identify itself as the recent-files panel")

local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local width = vim.api.nvim_win_get_width(win)

for _, line in ipairs(lines) do
    assert_true(
        vim.fn.strdisplaywidth(line) <= width,
        ("every row must fit inside the %d-column panel: %s"):format(width, line)
    )
end

local text = table.concat(lines, "\n")
assert_true(text:find("one.cpp", 1, true) ~= nil, "the panel should list recent files by name")
assert_true(text:find("Open file", 1, true) ~= nil, "the panel should offer an add row")

-- Clicking the ✕ on the first row forgets it.
local panel = require("config.panel")
local first = panel.entry_at(1)
assert_true(first ~= nil, "row 1 should carry an entry")

panel.act("forget", 1)
assert_true(not vim.tbl_contains(reloaded.list(), first.id), "the forgotten file should leave the list")
assert_true(vim.uv.fs_stat(first.id) ~= nil, "forgetting from the panel must not delete the file")

-- Opening a different panel kind replaces this one rather than stacking.
vim.g.projects_data_dir = vim.fs.joinpath(sandbox, "projects")
require("config.projects").panel()
assert_equal(panel.kind(), "projects", "opening another panel should replace the recent one")

panel.close()
assert_equal(panel.kind(), nil, "closing should clear the active panel")

vim.fn.delete(sandbox, "rf")

vim.cmd("qa!")
