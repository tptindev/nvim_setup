-- `<C-d>` has to feel like VS Code's: the first press selects the word under
-- the cursor, every press after that adds a cursor at the next occurrence, and
-- what you then type lands in all of them at once.
--
-- The whole scenario runs in a child Neovim rather than in this script.
-- multicursor.nvim installs its keymap layer and replays edits to its other
-- cursors from a `SafeState` autocmd, and `SafeState` never fires under
-- `nvim --headless -l`: script mode runs the file and exits without ever
-- entering the main loop. The child is headless too, but it does run the loop.
--
-- The child must also type with `nvim_input` and not `nvim_feedkeys`. The
-- plugin wraps `nvim_feedkeys` to remember which keys it fed itself, and
-- subtracts them from the typed-key stream again (`feedkeys-manager.lua`), so
-- keys fed that way are seen as synthetic and never reach the other cursors.
-- Characters also have to arrive one at a time: a whole `cbar` in one
-- `nvim_input` is mirrored to the other cursors live *and* replayed when insert
-- mode ends, which writes "barbar" -- an artifact of the burst, not of typing.

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
local plugin_root = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "multicursor.nvim")
local pass_marker = "multicursor tests passed"

if not vim.g.multicursor_child then
    assert_true(
        vim.uv.fs_stat(plugin_root) ~= nil,
        "multicursor.nvim is not installed yet -- run :Lazy install first"
    )

    local child = vim.system({
        vim.v.progpath,
        "--headless",
        "-u",
        "NONE",
        "--cmd",
        "lua vim.g.multicursor_child = true",
        "--cmd",
        "luafile " .. vim.fn.fnameescape(script_path),
    }, { text = true }):wait(60000)

    local output = (child.stdout or "") .. (child.stderr or "")
    if not output:find(pass_marker, 1, true) then
        error("the child Neovim did not finish the scenario:\n" .. output)
    end

    print(pass_marker)
    vim.cmd("qa!")
    return
end

package.path = table.concat({
    vim.fs.joinpath(config_root, "lua", "?.lua"),
    vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
    vim.fs.joinpath(plugin_root, "lua", "?.lua"),
    vim.fs.joinpath(plugin_root, "lua", "?", "init.lua"),
    package.path,
}, ";")

vim.g.projects_data_dir = vim.fs.normalize(vim.fn.tempname())
-- config/lazy.lua owns this in a real session; nothing loads lazy.nvim here.
vim.g.mapleader = " "

-- Run the plugin spec's own `config` instead of calling `setup()` directly, so
-- the keymap layer it registers is under test too.
local spec = dofile(vim.fs.joinpath(config_root, "lua", "plugins", "multicursor.lua"))
assert_equal(spec[1], "jake-stewart/multicursor.nvim", "the spec should install multicursor.nvim")
spec.config()

require("config.keymaps")

local mc = require("multicursor-nvim")

---The line of every cursor, sorted and joined, so "one cursor per match" is a
---plain string comparison.
local function cursor_lines()
    local lines = {}
    mc.action(function(ctx)
        ctx:forEachCursor(function(cursor)
            table.insert(lines, cursor:getPos()[1])
        end)
    end)
    table.sort(lines)
    return table.concat(lines, ",")
end

local function reset()
    vim.cmd("enew!")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "local foo = 1",
        "print(foo)",
        "print(foo)",
    })
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
end

local function selection()
    return vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."))[1]
end

local function buffer_text()
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "|")
end

-- Each step is typed keys or an assertion; they are run one per tick so the
-- main loop reaches a safe state between them, like it does between keystrokes.
local steps = {
    reset,

    -- The first press only selects the word, exactly like VS Code. That is also
    -- what lets the visual-mode mapping match a selection rather than a word.
    function() vim.api.nvim_input("<C-d>") end,
    function()
        assert_equal(vim.api.nvim_get_mode().mode, "v", "<C-d> should leave a charwise visual selection")
        assert_equal(selection(), "foo", "<C-d> should select the word under the cursor")
        assert_true(not mc.hasCursors(), "the first <C-d> should not add a cursor yet")
    end,

    function() vim.api.nvim_input("<C-d>") end,
    function()
        assert_equal(mc.numCursors(), 2, "the second <C-d> should add a cursor at the next match")
    end,

    function() vim.api.nvim_input("<C-d>") end,
    function()
        assert_equal(mc.numCursors(), 3, "the third <C-d> should add a cursor at the last match")
        assert_equal(cursor_lines(), "1,2,3", "one cursor should sit on each occurrence of the word")
        -- The layer only exists while there are cursors, which is what keeps
        -- `<Esc>` free to leave insert mode and close floats the rest of the time.
        assert_equal(vim.fn.maparg("<Esc>", "n", false, true).buffer, 1, "the layer's <Esc> should be buffer-local")
    end,

    -- Typing once has to rewrite every occurrence.
    function() vim.api.nvim_input("c") end,
    function() vim.api.nvim_input("b") end,
    function() vim.api.nvim_input("a") end,
    function() vim.api.nvim_input("r") end,
    function() vim.api.nvim_input("<Esc>") end,
    function()
        assert_equal(buffer_text(), "local bar = 1|print(bar)|print(bar)", "the change should land in all three cursors")
    end,

    function() vim.api.nvim_input("<Esc>") end,
    function()
        assert_true(not mc.hasCursors(), "<Esc> should collapse back to a single cursor")
        assert_equal(vim.fn.maparg("<Esc>", "n", false, true).buffer, nil, "the layer should go away with the cursors")
    end,

    -- The terminal fallbacks: Ctrl+Shift and Ctrl+Alt combinations only reach
    -- Neovim from a GUI, so `<leader>m` has to reach the same actions. `<leader>`
    -- is a space, and `nvim_input` does not expand the `<leader>` notation.
    reset,
    function() vim.api.nvim_input(" ma") end,
    function()
        assert_equal(mc.numCursors(), 3, "<leader>ma should add a cursor at every match")
        assert_equal(cursor_lines(), "1,2,3", "<leader>ma should place one cursor per occurrence")
        mc.clearCursors()
    end,

    reset,
    function() vim.api.nvim_input(" mj") end,
    function()
        assert_equal(mc.numCursors(), 2, "<leader>mj should add a cursor on the line below")
        assert_equal(cursor_lines(), "1,2", "<leader>mj should add the cursor directly below the main one")
        mc.clearCursors()
    end,

    -- A burst of `<C-d>`, the way holding the key down produces one. Both
    -- presses sit in the typeahead together, and multicursor flushes that
    -- typeahead through `feedkeys()` from inside its own action -- so without
    -- the guard in `keymaps.lua` the second press re-enters `core.action`,
    -- which raises "An action is already being performed", prints a stack
    -- trace and loses the cursor the first press was adding (leaving 1).
    reset,
    function() vim.api.nvim_input("<C-d>") end,
    function() vim.api.nvim_input("<C-d><C-d>") end,
    function()
        assert_equal(mc.numCursors(), 2, "a burst of <C-d> should still add its cursor")
        mc.clearCursors()
    end,

    function()
        print(pass_marker)
    end,
}

local index = 0
local function run_next()
    index = index + 1
    local step = steps[index]
    if not step then
        vim.cmd("qa!")
        return
    end

    local ok, err = pcall(step)
    if not ok then
        print("step " .. index .. " failed: " .. tostring(err))
        vim.cmd("qa!")
        return
    end

    vim.defer_fn(run_next, 100)
end

vim.defer_fn(run_next, 100)
