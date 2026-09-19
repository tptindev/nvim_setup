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
vim.cmd("setfiletype python")

assert_equal(vim.bo.tabstop, 4, "expected Python buffers to use a 4-space tabstop")
assert_equal(vim.bo.shiftwidth, 4, "expected Python buffers to use a 4-space shiftwidth")
assert_equal(vim.bo.softtabstop, 4, "expected Python buffers to use a 4-space softtabstop")
assert_truthy(vim.bo.expandtab, "expected Python buffers to expand tabs into spaces")

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

assert_truthy(
    vim.tbl_contains(mason_setup_opts.ensure_installed, "basedpyright"),
    "expected basedpyright to be installed for Python"
)
assert_truthy(
    vim.tbl_contains(mason_setup_opts.ensure_installed, "ruff"),
    "expected ruff to be installed (it also provides the CLI conform formats with)"
)

local pyright = configured_servers.basedpyright
assert_truthy(pyright ~= nil, "expected basedpyright to be configured")
assert_equal(pyright.single_file_support, true, "expected basedpyright to support standalone Python files")
assert_equal(pyright.workspace_required, false, "expected basedpyright to start without a project root")
assert_equal(
    pyright.settings.basedpyright.disableOrganizeImports,
    true,
    "expected basedpyright to leave import sorting to ruff"
)

local ruff = configured_servers.ruff
assert_truthy(ruff ~= nil, "expected the ruff language server to be configured")
assert_equal(ruff.workspace_required, false, "expected ruff to start without a project root")

-- Two servers on one buffer means two hover popups unless ruff's is dropped.
local fake_client = { server_capabilities = { hoverProvider = true } }
ruff.on_attach(fake_client)
assert_equal(
    fake_client.server_capabilities.hoverProvider,
    false,
    "expected ruff to yield hover to basedpyright"
)

local conform_spec = require("plugins.conform")
local python_formatters = conform_spec.opts.formatters_by_ft.python
assert_equal(python_formatters[1], "ruff_fix", "expected lint fixes to run before formatting")
assert_equal(python_formatters[2], "ruff_organize_imports", "expected imports to be sorted before formatting")
assert_equal(python_formatters[3], "ruff_format", "expected ruff_format to lay out the final result")

-- Without a condition, every save before ruff finishes installing errors.
for _, name in ipairs({ "ruff_fix", "ruff_organize_imports", "ruff_format" }) do
    assert_truthy(
        type(conform_spec.opts.formatters[name].condition) == "function",
        "expected " .. name .. " to skip quietly when ruff is missing"
    )
end

local treesitter_spec = require("plugins.treesitter")
assert_equal(treesitter_spec[1], "nvim-treesitter/nvim-treesitter", "expected treesitter plugin spec to target nvim-treesitter")

vim.cmd("qa!")
