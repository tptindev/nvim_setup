-- Navigating with the `g` keys must not drop a quickfix split at the bottom.
--
-- `vim.lsp.buf.definition()` / `.references()` and friends push everything past
-- a single result into the quickfix list and run `botright copen`
-- (runtime/lua/vim/lsp/buf.lua). The keymaps route through fzf-lua instead, so
-- multiple results land in a float and a lone result jumps straight there.

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

vim.g.projects_data_dir = vim.fs.normalize(vim.fn.tempname())

-- Stand in for fzf-lua: the keymaps resolve it at call time, so recording which
-- picker each key asks for proves where the key actually goes. Checking the
-- mapping description would not — the built-in that opens quickfix carries the
-- same description.
local picked = {}
package.loaded["fzf-lua"] = setmetatable({}, {
    __index = function(_, name)
        return function()
            table.insert(picked, name)
        end
    end,
})

require("config.keymaps")

local path = vim.fn.tempname() .. ".txt"
vim.fn.writefile({ "int shader = 1;", "use(shader);", "use(shader);" }, path)
vim.cmd("edit " .. vim.fn.fnameescape(path))

local buf = vim.api.nvim_get_current_buf()
local uri = vim.uri_from_bufnr(buf)

---Two hits, which is exactly the case the built-in handler sends to quickfix.
local function locations()
    return {
        { uri = uri, range = { start = { line = 1, character = 4 }, ["end"] = { line = 1, character = 10 } } },
        { uri = uri, range = { start = { line = 2, character = 4 }, ["end"] = { line = 2, character = 10 } } },
    }
end

local function fake_server()
    local closing = false

    return {
        request = function(method, _, callback)
            if method == "initialize" then
                callback(nil, {
                    capabilities = {
                        definitionProvider = true,
                        referencesProvider = true,
                        documentSymbolProvider = true,
                    },
                })
            elseif method == "textDocument/definition" or method == "textDocument/references" then
                callback(nil, locations())
            elseif method == "shutdown" then
                callback(nil, nil)
            end

            return true, 1
        end,
        notify = function()
            return true
        end,
        is_closing = function()
            return closing
        end,
        terminate = function()
            closing = true
        end,
    }
end

local client_id = vim.lsp.start({ name = "goto-test", cmd = fake_server }, { bufnr = buf })
assert_true(client_id ~= nil, "the stand-in language server should attach")

vim.wait(2000, function()
    return vim.fn.maparg("gd", "n", false, true).desc == "Goto definition"
end)

-- Every `g` key that can yield more than one result must reach the picker
-- rather than the built-in that opens quickfix. `grr`/`gri`/`grt`/`gO` are
-- Neovim's own global defaults, so these have to win as buffer-local mappings.
local windows_before = #vim.api.nvim_list_wins()

for lhs, picker in pairs({
    gd = "lsp_definitions",
    gD = "lsp_declarations",
    grr = "lsp_references",
    gri = "lsp_implementations",
    grt = "lsp_typedefs",
    gO = "lsp_document_symbols",
}) do
    local map = vim.fn.maparg(lhs, "n", false, true)
    assert_equal(map.buffer, 1, lhs .. " should be buffer-local so it beats the global default")
    assert_true(map.callback ~= nil, lhs .. " should be backed by a callback")

    picked = {}
    map.callback()
    assert_equal(picked[1], picker, lhs .. " should ask the picker, not the built-in handler")
end

-- None of that may disturb the window layout the user is working in.
assert_equal(#vim.api.nvim_list_wins(), windows_before, "navigating must not add a window")
assert_equal(#vim.fn.getqflist(), 0, "navigating must not populate the quickfix list")

-- Prove the thing being avoided: the built-in really does force a split open.
vim.fn.setqflist({}, "f")
assert_equal(#vim.fn.getqflist(), 0, "the quickfix list should start empty")

vim.lsp.buf.definition()
vim.wait(2000, function()
    return #vim.fn.getqflist() > 0
end)

local opened = false
for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.fn.getwininfo(win)[1].quickfix == 1 then
        opened = true
    end
end

assert_true(opened, "vim.lsp.buf.definition should be the thing that opens quickfix")
vim.cmd("cclose")

-- `<leader>lc` closes it again, and `]q`/`[q` walk it without opening a window.
for _, lhs in ipairs({ "]q", "[q" }) do
    assert_true(vim.fn.maparg(lhs, "n") ~= "", lhs .. " should walk the quickfix list")
end
assert_true(vim.fn.maparg("<leader>lc", "n") ~= "", "<leader>lc should close the quickfix window")

print("lsp_goto_no_quickfix: ok")
vim.cmd("qa!")
