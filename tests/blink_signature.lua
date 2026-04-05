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

local spec = require("plugins.blink")
local opts = spec.opts

assert_equal(spec[1], "saghen/blink.cmp", "expected blink plugin spec to target saghen/blink.cmp")
assert_truthy(type(opts) == "table", "expected blink spec to expose opts")
assert_truthy(type(opts.signature) == "table", "expected blink opts to configure signature help")
assert_equal(opts.signature.enabled, true, "expected blink signature help to be enabled")

vim.cmd("qa!")
