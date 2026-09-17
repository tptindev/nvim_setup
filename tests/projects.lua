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

-- Keep the real recent-project list untouched.
local sandbox = vim.fs.normalize(vim.fn.tempname())
vim.g.projects_data_dir = sandbox

local projects = require("config.projects")

-- Build a throwaway C++/CMake project on disk.
local workspace = vim.fs.joinpath(sandbox, "workspace")
local project_root = vim.fs.joinpath(workspace, "demo")
local nested = vim.fs.joinpath(project_root, "src", "engine")

vim.fn.mkdir(nested, "p")
vim.fn.writefile({ "cmake_minimum_required(VERSION 3.20)" }, vim.fs.joinpath(project_root, "CMakeLists.txt"))

local source_file = vim.fs.joinpath(nested, "main.cpp")
vim.fn.writefile({ "int main() { return 0; }" }, source_file)

-- detect() walks up to the nearest root marker.
assert_equal(projects.detect(nested), project_root, "detect should find the CMakeLists.txt root from a nested directory")
assert_equal(projects.detect(source_file), project_root, "detect should accept a file path")

-- The recent list starts empty and is ordered most-recent-first.
assert_equal(#projects.list(), 0, "a fresh store should have no projects")

local other_root = vim.fs.joinpath(workspace, "other")
vim.fn.mkdir(other_root, "p")

assert_equal(projects.add(project_root), project_root, "add should return the canonical root")
projects.add(other_root)
assert_equal(projects.list()[1], other_root, "the most recently added project should come first")
assert_equal(#projects.list(), 2, "both projects should be listed")

-- Re-adding moves an entry back to the front instead of duplicating it.
projects.add(project_root)
assert_equal(projects.list()[1], project_root, "re-adding should move the project to the front")
assert_equal(#projects.list(), 2, "re-adding should not duplicate the entry")

-- Non-directories are rejected.
assert_equal(projects.add(source_file), nil, "add should reject a file path")
assert_equal(projects.add(vim.fs.joinpath(workspace, "does-not-exist")), nil, "add should reject a missing directory")

projects.remove(other_root)
assert_equal(#projects.list(), 1, "remove should drop the entry")
assert_equal(projects.list()[1], project_root, "remove should keep the other entries")

-- set_root changes the cwd and normalizes the path.
assert_equal(projects.set_root(project_root), project_root, "set_root should return the normalized root")
assert_equal(projects.current(), project_root, "set_root should change the cwd")

-- Sessions round-trip through the sandbox.
vim.cmd("set noswapfile")
assert_equal(projects.save_session(), false, "an editor with no real buffer should not write a session")

vim.cmd("edit " .. vim.fn.fnameescape(source_file))
assert_true(projects.save_session(), "save_session should write a session once a file is open")

vim.cmd("silent! %bwipeout!")
assert_true(projects.load_session(), "load_session should restore a saved session")

local restored = vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
assert_equal(restored, vim.fs.normalize(source_file), "the restored session should reopen the source file")

projects.delete_session()
assert_equal(projects.load_session(), false, "a deleted session should no longer load")

-- setup() registers the user commands exactly once.
vim.cmd("cd " .. vim.fn.fnameescape(config_root))
projects.setup({ auto_save_session = false })
projects.setup({ auto_save_session = false })

for _, name in ipairs({ "ProjectOpen", "ProjectAdd", "ProjectRemove", "ProjectRoot", "ProjectSessionSave", "ProjectSessionLoad", "ProjectSessionDelete" }) do
    assert_true(vim.fn.exists(":" .. name) == 2, name .. " should be defined by setup()")
end

vim.fn.delete(sandbox, "rf")

vim.cmd("qa!")
