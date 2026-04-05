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

local spec = require("plugins.which-key")
local opts = spec.opts

assert_equal(spec[1], "folke/which-key.nvim", "expected which-key plugin spec to target folke/which-key.nvim")
assert_truthy(type(opts) == "table", "expected which-key spec to expose opts")
assert_truthy(type(opts.triggers) == "table", "expected which-key opts to define manual triggers")

local leader_trigger
for _, trigger in ipairs(opts.triggers) do
    if trigger[1] == "<leader>" then
        leader_trigger = trigger
        break
    end
end

assert_truthy(leader_trigger ~= nil, "expected which-key to define a manual <leader> trigger")
assert_equal(vim.inspect(leader_trigger.mode), vim.inspect({ "n", "v" }), "expected <leader> trigger to cover normal and visual mode")

vim.cmd("qa!")
