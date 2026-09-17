-- A folder dropped on Neovide arrives as `:drop <dir>`, which puts the
-- directory on the argument list. Vim keeps a listed buffer alive for every
-- arglist entry, so deleting the buffer alone is not enough: it returns as a
-- tab with a folder icon, and `mksession` writes it out as `$argadd <dir>` /
-- `badd <dir>` so every later session load resurrects it.

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(("%s\nexpected: %s\nactual: %s"):format(message, vim.inspect(expected), vim.inspect(actual)))
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

local project_root = vim.fs.joinpath(sandbox, "dropped")
vim.fn.mkdir(vim.fs.joinpath(project_root, "src"), "p")
vim.fn.writefile({ "cmake_minimum_required(VERSION 3.20)" }, vim.fs.joinpath(project_root, "CMakeLists.txt"))

local source_file = vim.fs.joinpath(project_root, "src", "main.cpp")
vim.fn.writefile({ "int main() { return 0; }" }, source_file)

local function directory_buffers()
    local found = {}

    for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        local name = vim.api.nvim_buf_get_name(info.bufnr)
        if name ~= "" and vim.fn.isdirectory(name) == 1 then
            table.insert(found, name)
        end
    end

    return found
end

-- Exactly what `neovide.private.dropfile` runs for a dropped folder.
vim.api.nvim_cmd({ cmd = "drop", args = { vim.fn.fnameescape(project_root) }, mods = { tab = 1 } }, {})

assert_equal(#vim.fn.argv(), 1, "the drop should put the folder on the argument list")
assert_equal(#directory_buffers(), 1, "the drop should create a listed directory buffer")

-- Opening the project is what the BufNew/BufEnter hook does with that buffer.
vim.cmd("edit " .. vim.fn.fnameescape(source_file))
projects.open(project_root)

assert_equal(#vim.fn.argv(), 0, "opening a project should clear directories from the argument list")
assert_equal(#directory_buffers(), 0, "opening a project should leave no directory buffer behind")

-- An empty editor skips the session write entirely (`has_real_buffer` is false),
-- so the reset on the way into a project has to clear the arglist by itself.
vim.cmd("silent! %bwipeout!")
vim.cmd("argadd " .. vim.fn.fnameescape(project_root))
assert_equal(#vim.fn.argv(), 1, "the arglist should hold the directory before the switch")

projects.open(project_root)

assert_equal(#vim.fn.argv(), 0, "a project switch from an empty editor should still clear the arglist")
assert_equal(#directory_buffers(), 0, "a project switch from an empty editor should leave no directory buffer")

-- A session must never carry the folder back in.
vim.cmd("edit " .. vim.fn.fnameescape(source_file))
vim.cmd("argadd " .. vim.fn.fnameescape(project_root))
assert_equal(#vim.fn.argv(), 1, "the arglist should hold the directory before saving")

projects.save_session(project_root)

local slug = (vim.fs.normalize(project_root):gsub("[^%w]", "_"))
local session = vim.fs.joinpath(sandbox, "sessions", slug .. ".vim")
assert_equal(vim.fn.filereadable(session), 1, "the session should have been written")

for _, line in ipairs(vim.fn.readfile(session)) do
    if line:match("^%$?argadd") or line:match("^badd") then
        local target = line:gsub("^%S+%s+", ""):gsub("^%+%d+%s+", "")
        assert_equal(
            vim.fn.isdirectory(vim.fn.fnamemodify(target, ":p")),
            0,
            "the session recorded a directory: " .. line
        )
    end
end

print("projects_dropped_folder: ok")
vim.cmd("qa!")
