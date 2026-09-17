-- Autosave writes a file back on InsertLeave / BufLeave / WinLeave / FocusLost,
-- skips everything that is not an editable file, and never runs the formatter.
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

local autosave = require("config.autosave")
autosave.setup()
autosave.setup() -- idempotent

local sandbox = vim.fn.tempname()
vim.fn.mkdir(sandbox, "p")

local path = vim.fs.joinpath(sandbox, "note.txt")
vim.fn.writefile({ "first" }, path)

vim.cmd("edit " .. vim.fn.fnameescape(path))
local buf = vim.api.nvim_get_current_buf()

---@return string[]
local function on_disk()
    return vim.fn.readfile(path)
end

-- Leaving insert mode writes the buffer.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "second" })
assert_truthy(vim.bo[buf].modified, "expected the buffer to be modified")
assert_equal(on_disk()[1], "first", "expected nothing written yet")

vim.api.nvim_exec_autocmds("InsertLeave", { buffer = buf })

assert_equal(on_disk()[1], "second", "expected InsertLeave to write the buffer")
assert_equal(vim.bo[buf].modified, false, "expected the buffer to be clean after autosave")

-- The other events write too.
for _, event in ipairs({ "BufLeave", "WinLeave", "FocusLost" }) do
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { event })
    vim.api.nvim_exec_autocmds(event, { buffer = buf })
    assert_equal(on_disk()[1], event, "expected " .. event .. " to write the buffer")
end

-- Formatting is suppressed for the duration of the write and restored after.
local seen_during_write
vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = buf,
    callback = function()
        seen_during_write = vim.b[buf].disable_autoformat
    end,
})

vim.b[buf].disable_autoformat = nil
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "formatted" })
autosave.save(buf)

assert_equal(seen_during_write, true, "expected autosave to disable formatting while writing")
assert_equal(vim.b[buf].disable_autoformat, nil, "expected the formatting opt-out to be restored")

-- A manual opt-out survives an autosave.
vim.b[buf].disable_autoformat = false
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "kept" })
autosave.save(buf)
assert_equal(vim.b[buf].disable_autoformat, false, "expected an explicit opt-out value to be kept")

-- Buffers that must never be written on their own.
local scratch = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { "scratch" })
assert_equal(autosave.should_save(scratch), false, "expected a scratch buffer to be skipped")

local unnamed = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(unnamed, 0, -1, false, { "unnamed" })
assert_equal(autosave.should_save(unnamed), false, "expected an unnamed buffer to be skipped")

local missing_dir = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(missing_dir, vim.fs.joinpath(sandbox, "nope", "file.txt"))
vim.api.nvim_buf_set_lines(missing_dir, 0, -1, false, { "x" })
assert_equal(autosave.should_save(missing_dir), false, "expected a buffer under a missing directory to be skipped")

vim.bo[buf].filetype = "gitcommit"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "commit message" })
assert_equal(autosave.should_save(buf), false, "expected a commit message to be written by hand only")
vim.bo[buf].filetype = "text"

-- The opt-outs.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "disabled" })
vim.b[buf].autosave_disable = true
assert_equal(autosave.should_save(buf), false, "expected the buffer opt-out to hold")
vim.b[buf].autosave_disable = nil

vim.g.autosave_disable = true
assert_equal(autosave.should_save(buf), false, "expected the global opt-out to hold")
vim.g.autosave_disable = nil

assert_equal(autosave.should_save(buf), true, "expected autosave to resume once the opt-outs are gone")

vim.cmd("qa!")
