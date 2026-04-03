local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(("%s\nexpected: %s\nactual: %s"):format(message, expected, actual))
    end
end

local script_path = vim.fs.normalize(debug.getinfo(1, "S").source:sub(2))
local config_root = vim.fs.dirname(vim.fs.dirname(script_path))
local project_root = vim.fs.joinpath(config_root, "lua")

package.path = table.concat({
    vim.fs.joinpath(config_root, "lua", "?.lua"),
    vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
    package.path,
}, ";")

vim.cmd("set hidden")
vim.cmd("set noswapfile")
vim.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(config_root, "README.md")))
vim.cmd("vsplit")
vim.cmd("enew")
vim.bo.buftype = "nofile"
vim.cmd("wincmd h")

require("config.projects").set_root(project_root)

local before = vim.fs.normalize(vim.fn.getcwd())
assert_equal(before, project_root, "sanity check failed: project cwd did not switch to the project root")

vim.cmd("bdelete")

local after = vim.fs.normalize(vim.fn.getcwd())
assert_equal(after, project_root, "closing the last editor buffer should preserve the project cwd")

vim.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(config_root, "README.md")))
vim.cmd("badd " .. vim.fn.fnameescape(vim.fs.joinpath(config_root, "docs", "cheatsheet.md")))

require("config.buffers").quit()

local current_name = vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
local expected_name = vim.fs.normalize(vim.fs.joinpath(config_root, "docs", "cheatsheet.md"))
assert_equal(current_name, expected_name, "smart quit should close the current buffer and switch to another editor buffer")
assert_equal(vim.fs.normalize(vim.fn.getcwd()), project_root, "smart quit should preserve the project cwd")

require("config.buffers").quit()

local current_buf = vim.api.nvim_get_current_buf()
assert_equal(vim.bo[current_buf].buftype, "nofile", "smart quit should keep Neovim open with a placeholder after closing the last editor buffer")
assert_equal(vim.fs.normalize(vim.fn.getcwd()), project_root, "smart quit should keep the project cwd after closing the last editor buffer")

vim.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(config_root, "README.md")))
vim.cmd("SmartBwipeout")

local wiped_buf = vim.api.nvim_get_current_buf()
assert_equal(vim.bo[wiped_buf].buftype, "nofile", "raw bwipeout on the last editor buffer should keep Neovim open with a placeholder")
assert_equal(vim.fs.normalize(vim.fn.getcwd()), project_root, "raw bwipeout on the last editor buffer should preserve the project cwd")

vim.cmd("qa!")
