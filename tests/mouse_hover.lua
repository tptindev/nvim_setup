-- Pointer affordances: hover docs under the mouse and Ctrl+click to definition.
--
-- `<MouseMove>` is shared — bufferline binds it for its tab hover and re-emits
-- it from an <expr> mapping, and a re-emitted key is not mapped again, so the
-- last binding owns it. This drives the real chain with a stand-in for
-- bufferline and an in-process LSP server, so it needs neither a UI nor mason.

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

-- keymaps.lua calls projects.setup(), which records projects and writes
-- sessions; point that store somewhere disposable before loading it.
vim.g.projects_data_dir = vim.fs.normalize(vim.fn.tempname())

-- Loading the real keymaps gets both halves of the feature: mouse.setup()
-- registers the LspAttach hook that binds hover, and <C-LeftMouse> is declared
-- here alongside every other keymap.
require("config.keymaps")

-- Stand in for bufferline: claim the key first and count the calls that the
-- hover handler forwards to it.
local forwarded = 0
vim.keymap.set({ "", "i" }, "<MouseMove>", function()
    forwarded = forwarded + 1
    return "<MouseMove>"
end, { expr = true, desc = "stand-in for bufferline tab hover" })

-- `demo_symbol` sits at bytes 7..17 of line 1.
local asked_at = nil

local function fake_server()
    local closing = false

    return {
        request = function(method, params, callback)
            if method == "initialize" then
                callback(nil, { capabilities = { hoverProvider = true } })
            elseif method == "textDocument/hover" then
                asked_at = params.position
                callback(nil, {
                    contents = { kind = "markdown", value = "## demo_symbol\n\nDocs from the server." },
                    range = {
                        start = { line = params.position.line, character = 6 },
                        ["end"] = { line = params.position.line, character = 17 },
                    },
                })
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

local path = vim.fn.tempname() .. ".txt"
vim.fn.writefile({ "local demo_symbol = 1", "print(demo_symbol)" }, path)
vim.cmd("edit " .. vim.fn.fnameescape(path))

local win = vim.api.nvim_get_current_win()
local client_id = vim.lsp.start({ name = "hover-test", cmd = fake_server }, { bufnr = vim.api.nvim_get_current_buf() })
assert_true(client_id ~= nil, "the stand-in language server should attach")

---@param column integer 1-based byte column
local function point_at(column)
    vim.fn.getmousepos = function()
        return { winid = win, line = 1, column = column, screenrow = 3, screencol = column }
    end
end

local function floats()
    local found = {}

    for _, id in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(id).relative ~= "" then
            table.insert(found, id)
        end
    end

    return found
end

local function move_pointer()
    vim.fn.maparg("<MouseMove>", "n", false, true).callback()
end

-- LspAttach is what binds the hover handler, and it must land on top of the
-- stand-in rather than replacing it.
vim.wait(2000, function()
    local map = vim.fn.maparg("<MouseMove>", "n", false, true)
    return type(map) == "table" and map.desc == "LSP hover under the pointer"
end)

assert_equal(
    vim.fn.maparg("<MouseMove>", "n", false, true).desc,
    "LSP hover under the pointer",
    "the hover handler should own <MouseMove> after LspAttach"
)

-- Resting on the symbol asks the server and shows what it answers.
point_at(8)
move_pointer()
assert_equal(forwarded, 1, "the handler must forward to the mapping it replaced")

vim.wait(3000, function()
    return #floats() > 0
end)

local open = floats()
assert_equal(#open, 1, "hovering a symbol should open exactly one float")
assert_equal(asked_at.line, 0, "the request should use the hovered line, not the cursor line")
assert_equal(asked_at.character, 7, "the request should use the hovered column, not the cursor column")

local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(open[1]), 0, -1, false), " ")
assert_true(text:find("demo_symbol", 1, true) ~= nil, "the float should show the server's documentation")

-- Drifting inside the range the server reported keeps the same float up.
point_at(12)
move_pointer()
assert_equal(floats()[1], open[1], "moving within the symbol should not tear the float down")

-- Leaving the symbol closes it.
point_at(1)
move_pointer()
assert_equal(#floats(), 0, "moving off the symbol should close the float")

-- Ctrl+click reaches both modes; VSCode has no modes, so insert counts too.
for _, mode in ipairs({ "n", "i" }) do
    assert_equal(
        vim.fn.maparg("<C-LeftMouse>", mode, false, true).desc,
        "Goto definition under the pointer",
        "<C-LeftMouse> should be mapped in " .. mode .. " mode"
    )
end

print("mouse_hover: ok")
vim.cmd("qa!")
