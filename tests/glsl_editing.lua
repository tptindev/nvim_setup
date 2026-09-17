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

local shader_extensions = {
    "glsl",
    "vert",
    "frag",
    "geom",
    "comp",
    "tesc",
    "tese",
    "vs",
    "fs",
    "gs",
    "rgen",
    "rchit",
    "rmiss",
    "mesh",
    "task",
}

for _, ext in ipairs(shader_extensions) do
    local filename = "shader." .. ext
    local filetype = vim.filetype.match({ filename = filename })
    assert_equal(filetype, "glsl", "expected ." .. ext .. " files to be detected as glsl")
end

vim.cmd("enew")
vim.cmd("setfiletype glsl")

assert_equal(vim.bo.tabstop, 2, "expected GLSL buffers to use a 2-space tabstop")
assert_equal(vim.bo.shiftwidth, 2, "expected GLSL buffers to use a 2-space shiftwidth")
assert_equal(vim.bo.softtabstop, 2, "expected GLSL buffers to use a 2-space softtabstop")
assert_truthy(vim.bo.expandtab, "expected GLSL buffers to expand tabs into spaces")
assert_equal(vim.bo.commentstring, "// %s", "expected GLSL buffers to use C-style line comments")

local treesitter_spec = require("plugins.treesitter")
assert_equal(treesitter_spec[1], "nvim-treesitter/nvim-treesitter", "expected treesitter plugin spec to target nvim-treesitter")

vim.cmd("qa!")
