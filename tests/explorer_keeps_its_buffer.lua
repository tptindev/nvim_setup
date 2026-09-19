-- The neo-tree sidebar must never end up showing a file.
--
-- Two things used to steer one in there. `editor_window()` in
-- `plugins/bufferline.lua` accepted the current window whenever it was not a
-- float, so a tab click with the sidebar focused loaded the file into the
-- sidebar; neo-tree ejects it again from its own `BufEnter` handler, but that
-- eject runs `utils.open_file`, which restores the tree width through
-- `_compat.nvim_win_set_width` -- and that shim calls `vim.api.nvim_win_resize`
-- on `has("nvim-0.13")`, a function this build does not have, so it throws and
-- can leave the file deleted and never reopened.
--
-- Like `tests/multicursor.lua`, the scenario runs in a child Neovim: it needs
-- the real config (lazy.nvim, neo-tree, bufferline) and a main loop, and
-- `nvim --headless -l` provides neither.

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
local pass_marker = "explorer tests passed"

if not vim.g.explorer_child then
    local child = vim.system({
        vim.v.progpath,
        "--headless",
        "--cmd",
        "lua vim.g.explorer_child = true",
        "--cmd",
        "luafile " .. vim.fn.fnameescape(script_path),
    }, { text = true }):wait(120000)

    local output = (child.stdout or "") .. (child.stderr or "")
    if not output:find(pass_marker, 1, true) then
        error("the child Neovim did not finish the scenario:\n" .. output)
    end

    print(pass_marker)
    vim.cmd("qa!")
    return
end

local file_a = vim.fn.tempname() .. "_a.txt"
local file_b = vim.fn.tempname() .. "_b.txt"
vim.fn.writefile({ "aaa" }, file_a)
vim.fn.writefile({ "bbb" }, file_b)

local function sidebar_win()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
            return win
        end
    end
end

---Where a file ended up: the window showing it, or nil when nothing does.
local function window_showing(path)
    local buf = vim.fn.bufnr(path)
    if buf == -1 then
        return nil
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
            return win
        end
    end
end

local steps = {
    function()
        vim.cmd("edit " .. vim.fn.fnameescape(file_a))
        vim.cmd("edit " .. vim.fn.fnameescape(file_b))
        vim.cmd("Neotree show left")
        -- `User VeryLazy` never fires without a UI, so bufferline has to be
        -- pulled in by hand before its options exist.
        require("bufferline")
    end,

    -- The shim on the eject path has to work, whichever route gets there:
    -- `recent.lua` and the dashboard both open files with a plain `:edit`,
    -- which runs in whatever window has focus.
    function()
        local compat = require("neo-tree.utils._compat")
        local sidebar = sidebar_win()
        assert_true(sidebar ~= nil, "the sidebar should be open")
        assert_true(
            pcall(compat.nvim_win_set_width, sidebar, 32),
            "neo-tree's width shim must not throw -- it runs while a file is being ejected"
        )
        assert_true(
            pcall(compat.nvim_win_set_height, sidebar, 10),
            "neo-tree's height shim must not throw either"
        )
    end,

    -- A tab click with the sidebar focused must open the file elsewhere. The
    -- check has to happen in this same step: neo-tree ejects a file from the
    -- tree window on a `vim.schedule`, so by the next tick the sidebar looks
    -- untouched either way and only the window the click actually chose still
    -- tells the two apart.
    function()
        local sidebar = sidebar_win()
        vim.api.nvim_set_current_win(sidebar)
        require("bufferline.config").options.left_mouse_command(vim.fn.bufnr(file_a))
        assert_true(
            vim.api.nvim_get_current_win() ~= sidebar,
            "a tab click must not target the sidebar window, even when it has focus"
        )
    end,
    function()
        local sidebar = sidebar_win()
        assert_true(sidebar ~= nil, "the sidebar should survive a tab click")
        assert_equal(
            vim.bo[vim.api.nvim_win_get_buf(sidebar)].filetype,
            "neo-tree",
            "the sidebar window must still show the tree, not the file"
        )

        local shown = window_showing(file_a)
        assert_true(shown ~= nil, "the clicked file should be visible somewhere")
        assert_true(shown ~= sidebar, "the clicked file must not be the sidebar's buffer")
    end,

    -- `:edit` from inside the sidebar -- fine-cmdline, an fzf-lua pick, a
    -- recent-files panel row -- has to land somewhere else too.
    function()
        vim.api.nvim_set_current_win(sidebar_win())
        vim.cmd("edit " .. vim.fn.fnameescape(file_b))
    end,
    function() end,
    function()
        local sidebar = sidebar_win()
        assert_true(sidebar ~= nil, "the sidebar should survive an :edit")
        assert_equal(
            vim.bo[vim.api.nvim_win_get_buf(sidebar)].filetype,
            "neo-tree",
            "the sidebar window must still show the tree after :edit"
        )

        local shown = window_showing(file_b)
        assert_true(shown ~= nil, "the edited file should be visible somewhere")
        assert_true(shown ~= sidebar, "the edited file must not be the sidebar's buffer")
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

    vim.defer_fn(run_next, 400)
end

vim.defer_fn(run_next, 3000)
