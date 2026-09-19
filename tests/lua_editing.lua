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

require("config.options")

vim.cmd("enew")
vim.cmd("setfiletype lua")

-- stylua indents with 4 spaces, so anything narrower is undone on the next save.
assert_equal(vim.bo.tabstop, 4, "expected Lua buffers to use a 4-space tabstop")
assert_equal(vim.bo.shiftwidth, 4, "expected Lua buffers to use a 4-space shiftwidth")
assert_equal(vim.bo.softtabstop, 4, "expected Lua buffers to use a 4-space softtabstop")
assert_truthy(vim.bo.expandtab, "expected Lua buffers to expand tabs into spaces")

local lazydev_spec = require("plugins.lazydev")
assert_equal(lazydev_spec[1], "folke/lazydev.nvim", "expected the lazydev plugin spec to target folke/lazydev.nvim")
assert_equal(lazydev_spec.ft, "lua", "expected lazydev to load only for Lua buffers")

local plugins = require("plugins.init")
local has_lazydev = false
for _, spec in ipairs(plugins) do
    if spec[1] == "folke/lazydev.nvim" then
        has_lazydev = true
    end
end
assert_truthy(has_lazydev, "expected lazydev to be listed in plugins/init.lua (specs are not auto-discovered)")

local blink_spec = require("plugins.blink")
assert_truthy(
    vim.tbl_contains(blink_spec.opts.sources.default, "lazydev"),
    "expected blink.cmp to complete from lazydev in Lua buffers"
)
assert_equal(
    blink_spec.opts.sources.providers.lazydev.module,
    "lazydev.integrations.blink",
    "expected the lazydev source to point at its blink integration module"
)

local lsp_spec = require("plugins.lspconfig")
local configured_servers = {}
local original_lsp_config = vim.lsp.config

local original_mason = package.loaded["mason-lspconfig"]
package.loaded["mason-lspconfig"] = {
    setup = function() end,
}

local original_blink = package.loaded["blink.cmp"]
package.loaded["blink.cmp"] = {
    get_lsp_capabilities = function()
        return { textDocument = { completion = {} } }
    end,
}

vim.lsp.config = function(name, config)
    configured_servers[name] = config
end

lsp_spec.config()

vim.lsp.config = original_lsp_config
package.loaded["mason-lspconfig"] = original_mason
package.loaded["blink.cmp"] = original_blink

local lua_ls = configured_servers.lua_ls
assert_truthy(lua_ls ~= nil, "expected lua_ls to be configured")
assert_equal(lua_ls.settings.Lua.runtime.version, "LuaJIT", "expected lua_ls to target Neovim's LuaJIT runtime")
assert_truthy(
    vim.tbl_contains(lua_ls.settings.Lua.diagnostics.globals, "vim"),
    "expected lua_ls to treat `vim` as a global"
)
-- conform falls back to the LSP formatter; lua_ls must not undo stylua's layout.
assert_equal(lua_ls.settings.Lua.format.enable, false, "expected lua_ls formatting to stay off so stylua owns Lua layout")
assert_equal(
    lua_ls.settings.Lua.workspace.library,
    nil,
    "expected the workspace library to come from lazydev rather than a static list"
)

local conform_spec = require("plugins.conform")
assert_truthy(vim.tbl_contains(conform_spec.opts.formatters_by_ft.lua, "stylua"), "expected Lua files to format with stylua")

vim.cmd("qa!")
