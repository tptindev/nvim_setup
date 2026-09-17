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
vim.g.projects_data_dir = sandbox

local projects = require("config.projects")

local alpha = vim.fs.joinpath(sandbox, "alpha")
local beta = vim.fs.joinpath(sandbox, "beta")
local gamma = vim.fs.joinpath(sandbox, "gamma")

for _, dir in ipairs({ alpha, beta, gamma }) do
    vim.fn.mkdir(dir, "p")
end

projects.add(alpha)
projects.add(beta)
assert_equal(#projects.list(), 2, "two projects should be recorded")

-- Opening the panel builds a window over the recent list.
vim.o.columns = 120
vim.o.lines = 40
projects.panel()

local win = vim.api.nvim_get_current_win()
local buf = vim.api.nvim_win_get_buf(win)

assert_true(vim.api.nvim_win_get_config(win).relative ~= "", "the panel should be a floating window")
assert_equal(vim.bo[buf].filetype, "clickable-panel", "the panel buffer should be tagged")
assert_equal(vim.b[buf].panel_kind, "projects", "the panel buffer should name its kind for the right-click menu")

local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local text = table.concat(lines, "\n")

-- Regression: a deep path (the sandbox lives under a long temp dir) must not
-- push the ✕ button outside the window, or it cannot be clicked.
local win_width = vim.api.nvim_win_get_width(win)
for _, line in ipairs(lines) do
    assert_true(
        vim.fn.strdisplaywidth(line) <= win_width,
        ("every row must fit inside the %d-column panel, got %d: %s"):format(win_width, vim.fn.strdisplaywidth(line), line)
    )
end

assert_true(text:find("beta", 1, true) ~= nil, "the panel should list the most recent project")
assert_true(text:find("alpha", 1, true) ~= nil, "the panel should list every project")
assert_true(text:find("Add folder", 1, true) ~= nil, "the panel should offer an add row")
assert_true(text:find("✕", 1, true) ~= nil, "each project row should carry a remove marker")

-- Every mouse binding the panel promises must exist.
for _, lhs in ipairs({ "<LeftRelease>", "<2-LeftMouse>", "<CR>", "d", "a", "q" }) do
    assert_true(vim.fn.maparg(lhs, "n", false, true).buffer == 1, lhs .. " should be mapped in the panel buffer")
end

-- Row 1 is the newest project (beta). Forget it through the panel action.
assert_equal(projects.list()[1], beta, "beta should be first")
projects.panel_act("forget", 1)

assert_equal(#projects.list(), 1, "forgetting should drop one project")
assert_equal(projects.list()[1], alpha, "the remaining project should be alpha")
assert_true(vim.uv.fs_stat(beta) ~= nil, "forgetting a project must not delete the directory")

-- The panel redraws itself after the change.
text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
assert_true(text:find("beta", 1, true) == nil, "the forgotten project should disappear from the panel")
assert_true(text:find("alpha", 1, true) ~= nil, "the remaining project should still be listed")

-- Adding from elsewhere refreshes an open panel.
projects.add(gamma)
projects.refresh_panel()
text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
assert_true(text:find("gamma", 1, true) ~= nil, "refresh_panel should pick up a project added elsewhere")

-- A click past the pad column hits the remove marker, a click before it opens.
-- Reach into the rendered row to check the hit column is inside the line.
local row_line = nil
for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find("gamma", 1, true) then
        row_line = index
        break
    end
end

assert_true(row_line ~= nil, "the panel should have a row for gamma")
assert_true(
    vim.api.nvim_buf_get_lines(buf, row_line - 1, row_line, false)[1]:sub(-3) == "✕",
    "the remove marker should be the last thing on a project row"
)

projects.close_panel()
assert_true(not vim.api.nvim_win_is_valid(win), "close_panel should close the window")

-- Toggling: open, then open again closes.
projects.panel()
local second = vim.api.nvim_get_current_win()
assert_true(vim.api.nvim_win_get_config(second).relative ~= "", "the panel should reopen")
projects.panel()
assert_true(not vim.api.nvim_win_is_valid(second), "calling panel() again should toggle it closed")

-- Acting with no panel open must not throw.
assert_equal(pcall(projects.panel_act, "forget", 1), true, "panel_act should fail softly with no panel")

assert_true(vim.fn.exists(":ProjectPanel") == 0, "ProjectPanel is registered by setup(), not on require")
projects.setup({ auto_save_session = false, open_directories = false })
assert_true(vim.fn.exists(":ProjectPanel") == 2, "setup() should register :ProjectPanel")

vim.fn.delete(sandbox, "rf")

vim.cmd("qa!")
