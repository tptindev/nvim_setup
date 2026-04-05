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

local which_key_spec = require("plugins.which-key")
assert_equal(which_key_spec[1], "folke/which-key.nvim", "expected which-key plugin spec to target folke/which-key.nvim")
assert_equal(which_key_spec.event, "VimEnter", "expected which-key to load on VimEnter so leader hints are ready immediately")

require("config.options")

vim.cmd("enew")
vim.cmd("setfiletype cpp")

assert_equal(vim.bo.tabstop, 2, "expected C++ buffers to use a 2-space tabstop")
assert_equal(vim.bo.shiftwidth, 2, "expected C++ buffers to use a 2-space shiftwidth")
assert_equal(vim.bo.softtabstop, 2, "expected C++ buffers to use a 2-space softtabstop")
assert_truthy(vim.bo.expandtab, "expected C++ buffers to expand tabs into spaces")

local lsp_spec = require("plugins.lspconfig")
local configured_servers = {}
local mason_setup_opts
local original_lsp_config = vim.lsp.config

local original_mason = package.loaded["mason-lspconfig"]
package.loaded["mason-lspconfig"] = {
    setup = function(opts)
        mason_setup_opts = opts
    end,
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

assert_truthy(type(mason_setup_opts) == "table", "expected mason-lspconfig.setup to be called")
assert_truthy(vim.tbl_contains(mason_setup_opts.ensure_installed, "clangd"), "expected clangd to stay installed")
assert_equal(configured_servers.clangd.single_file_support, true, "expected clangd to support standalone new C++ files")

vim.cmd("qa!")
