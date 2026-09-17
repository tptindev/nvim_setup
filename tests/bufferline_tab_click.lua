-- A click on a bufferline tab must open the file in an editor window. The
-- default `buffer %d` runs in the current window, so with the toggleterm float
-- focused the file was loaded into the overlay; toggleterm then lost its own
-- window (is_open() checks the window still shows its buffer), the next toggle
-- opened a second float, and the first could only be closed with <C-w>q.
local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(("%s\nexpected: %s\nactual: %s"):format(message, vim.inspect(expected), vim.inspect(actual)))
    end
end

local script_path = vim.fs.normalize(debug.getinfo(1, "S").source:sub(2))
local config_root = vim.fs.dirname(vim.fs.dirname(script_path))

package.path = table.concat({
    vim.fs.joinpath(config_root, "lua", "?.lua"),
    vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
    package.path,
}, ";")

local spec = require("plugins.bufferline")
assert_equal(spec[1], "akinsho/bufferline.nvim", "expected the spec to target akinsho/bufferline.nvim")

local click = spec.opts().options.left_mouse_command
assert_equal(type(click), "function", "expected left_mouse_command to be a function")

---A float on top of the editor window, focused, standing in for toggleterm.
---@return integer win
---@return integer buf
local function open_float()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = 20,
        height = 5,
        row = 1,
        col = 1,
        style = "minimal",
    })

    return win, buf
end

local editor_win = vim.api.nvim_get_current_win()
local editor_buf = vim.api.nvim_win_get_buf(editor_win)
local target = vim.api.nvim_create_buf(true, false)

local float_win, float_buf = open_float()
assert_equal(vim.api.nvim_get_current_win(), float_win, "expected the float to be focused")

click(target)

assert_equal(vim.api.nvim_win_get_buf(editor_win), target, "expected the clicked buffer to land in the editor window")
assert_equal(vim.api.nvim_get_current_win(), editor_win, "expected focus to move to the editor window")
assert_equal(vim.api.nvim_win_get_buf(float_win), float_buf, "expected the float to keep its own buffer")

-- From an ordinary window the click stays where it is.
vim.api.nvim_win_set_buf(editor_win, editor_buf)
local second = vim.api.nvim_create_buf(true, false)
click(second)
assert_equal(vim.api.nvim_win_get_buf(editor_win), second, "expected a click from a normal window to switch it")

-- The sidebar is not an editor window: with nothing else to use, nothing moves.
vim.api.nvim_set_current_win(float_win)
vim.bo[second].filetype = "neo-tree"
local third = vim.api.nvim_create_buf(true, false)
click(third)

assert_equal(vim.api.nvim_win_get_buf(editor_win), second, "expected the sidebar window to be left alone")
assert_equal(vim.api.nvim_win_get_buf(float_win), float_buf, "expected the float to be left alone")

vim.cmd("qa!")
