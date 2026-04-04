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

local colon_map = vim.fn.maparg(":", "n", false, true)
assert_truthy(type(colon_map) == "table" and next(colon_map) ~= nil, "expected normal-mode ':' mapping to exist")
assert_equal(colon_map.desc, "Use fine command line", "expected ':' mapping description to document the new behavior")
assert_truthy(type(colon_map.callback) == "function", "expected normal-mode ':' mapping to be backed by a Lua callback")

local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level)
    table.insert(notifications, { message = message, level = level })
end

colon_map.callback()
vim.notify = original_notify

assert_equal(#notifications, 1, "expected ':' callback to emit exactly one notification")
assert_equal(notifications[1].message, "Use <leader>: for fine command line", "expected ':' callback to guide the user toward <leader>:")
assert_equal(notifications[1].level, vim.log.levels.INFO, "expected ':' callback to use an info notification")

vim.cmd("qa!")
