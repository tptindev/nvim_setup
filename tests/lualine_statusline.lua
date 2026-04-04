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

local spec = require("plugins.lualine")
local opts = spec.opts()

assert_equal(spec[1], "nvim-lualine/lualine.nvim", "expected lualine plugin spec to target nvim-lualine/lualine.nvim")

assert_equal(opts.sections.lualine_a[1], "mode", "expected mode in lualine_a")
assert_equal(opts.sections.lualine_b[1], "branch", "expected branch to lead lualine_b")
assert_equal(opts.sections.lualine_b[2], "diff", "expected diff beside branch in lualine_b")

local filename_component = opts.sections.lualine_c[1]
assert_truthy(type(filename_component) == "table", "expected filename component config in lualine_c")
assert_equal(filename_component[1], "filename", "expected filename component in lualine_c")

assert_equal(opts.sections.lualine_x[1], "diagnostics", "expected diagnostics to lead lualine_x")
assert_truthy(type(opts.sections.lualine_x[2]) == "function", "expected lualine_x to include an LSP helper function")
assert_equal(opts.sections.lualine_y[1], "filetype", "expected filetype in lualine_y")
assert_equal(opts.sections.lualine_z[1], "progress", "expected progress in lualine_z")
assert_equal(opts.sections.lualine_z[2], "location", "expected location beside progress in lualine_z")

assert_truthy(type(opts.inactive_sections.lualine_c[1]) == "table", "expected inactive lualine_c filename config")
assert_equal(opts.inactive_sections.lualine_x[1], "location", "expected inactive lualine_x to keep only location")
assert_truthy(vim.tbl_contains(opts.options.disabled_filetypes.statusline, "dashboard"), "expected dashboard statusline to be disabled")

local lsp_component = opts.sections.lualine_x[2]
local original_get_clients = vim.lsp.get_clients

vim.lsp.get_clients = function()
    return {}
end
assert_equal(lsp_component(), "", "expected LSP helper to disappear when no clients are attached")

vim.lsp.get_clients = function(args)
    assert_truthy(type(args) == "table" and args.bufnr == 0, "expected LSP helper to query the current buffer")
    return {
        { name = "clangd" },
        { name = "null-ls" },
    }
end
assert_equal(lsp_component(), "LSP clangd, null-ls", "expected LSP helper to list attached client names")

vim.lsp.get_clients = original_get_clients

vim.cmd("qa!")
