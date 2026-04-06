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

local spec = require("plugins.render_md")

assert_equal(spec[1], "MeanderingProgrammer/render-markdown.nvim", "expected render-markdown plugin spec to target MeanderingProgrammer/render-markdown.nvim")
assert_truthy(type(spec.ft) == "table", "expected render-markdown to lazy-load by filetype")
assert_equal(spec.ft[1], "markdown", "expected render-markdown to load for markdown buffers")

vim.cmd("qa!")
