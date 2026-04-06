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

require("config.keymaps")

local user_commands = vim.api.nvim_get_commands({})
assert_truthy(user_commands.SmartWrite ~= nil, "expected SmartWrite user command to exist")

vim.cmd("enew")
vim.bo.buftype = "nofile"

local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level)
    table.insert(notifications, { message = message, level = level })
end

vim.cmd("SmartWrite")

vim.notify = original_notify

assert_equal(#notifications, 1, "expected SmartWrite to notify exactly once for special buffers")
assert_equal(notifications[1].message, "Current buffer cannot be written", "expected SmartWrite to explain why special buffers are skipped")
assert_equal(notifications[1].level, vim.log.levels.WARN, "expected SmartWrite to use a warning notification")

vim.cmd("qa!")
