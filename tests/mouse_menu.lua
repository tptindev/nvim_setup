local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(("%s\nexpected: %s\nactual: %s"):format(message, vim.inspect(expected), vim.inspect(actual)))
    end
end

local function assert_true(value, message)
    if not value then
        error(message)
    end
end

local script_path = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p"))
local config_root = vim.fs.dirname(vim.fs.dirname(script_path))

package.path = table.concat({
    vim.fs.joinpath(config_root, "lua", "?.lua"),
    vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
    package.path,
}, ";")

local mouse = require("config.mouse")

---Names of the entries currently in the PopUp menu.
---@return string[]
local function popup_items()
    local ok, output = pcall(function()
        return vim.api.nvim_exec2("menu PopUp", { output = true }).output
    end)

    if not ok then
        return {}
    end

    local items = {}
    for line in output:gmatch("[^\n]+") do
        local name = line:match("^%s*%d+%s+(%S.*)$")
        if name and name ~= "PopUp" then
            table.insert(items, name)
        end
    end

    return items
end

local function has_item(items, wanted)
    for _, name in ipairs(items) do
        if name == wanted then
            return true
        end
    end
    return false
end

mouse.setup()
mouse.setup() -- idempotent

-- Neovim's own popup handler must be gone, otherwise it errors on every
-- right-click trying to disable menu entries this config replaced.
assert_equal(
    #vim.api.nvim_get_autocmds({ group = "nvim.popupmenu" }),
    0,
    "the built-in popup menu autocmd should be cleared"
)

local ours = vim.api.nvim_get_autocmds({ group = "MouseContextMenu", event = "MenuPopup" })
assert_equal(#ours, 1, "setup() should register exactly one MenuPopup handler")

-- The editor menu is built on demand.
vim.cmd("set noswapfile")
vim.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(config_root, "README.md")))
vim.api.nvim_exec_autocmds("MenuPopup", { pattern = "*" })

local items = popup_items()
for _, wanted in ipairs({ "Cut", "Copy", "Paste", "Select All", "Go to Definition", "Format Buffer", "Copy Full Path", "Reveal in Explorer" }) do
    assert_true(has_item(items, wanted), "the editor menu should contain " .. wanted)
end

-- Rebuilding must not duplicate entries.
local first_count = #items
vim.api.nvim_exec_autocmds("MenuPopup", { pattern = "*" })
assert_equal(#popup_items(), first_count, "rebuilding the menu should not duplicate entries")

-- Path helpers write to the system clipboard register.
vim.fn.setreg("+", "")
mouse.copy_path()
assert_equal(
    vim.fs.normalize(vim.fn.getreg("+")),
    vim.fs.normalize(vim.fs.joinpath(config_root, "README.md")),
    "copy_path should yank the absolute path"
)

vim.fn.setreg("+", "")
mouse.copy_relative_path()
assert_true(vim.fn.getreg("+") ~= "", "copy_relative_path should yank something")

-- Explorer helpers must not throw when there is no explorer open.
local ok = pcall(mouse.tree, "open")
assert_true(ok, "tree() should fail softly outside the explorer")

assert_equal(pcall(mouse.tree_copy_path), true, "tree_copy_path should fail softly outside the explorer")

vim.cmd("qa!")
