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

local neovide = require("config.neovide")

-- Outside Neovide the module must do nothing at all.
vim.g.neovide = nil
local before = vim.o.guifont
assert_equal(neovide.setup(), false, "setup() should be a no-op without Neovide")
assert_equal(vim.o.guifont, before, "setup() should not touch guifont without Neovide")
assert_equal(vim.fn.maparg("<F11>", "n"), "", "setup() should not map keys without Neovide")

-- Inside Neovide it applies the font, the window settings and the zoom keys.
vim.g.neovide = true
assert_equal(neovide.setup(), true, "setup() should apply settings under Neovide")
assert_equal(vim.o.guifont, neovide.font, "setup() should set the GUI font")

-- The font must name a family that is actually installed, otherwise Neovide
-- silently falls back to a font without Nerd Font glyphs.
local primary = neovide.font:match("^([^,:]+)")
assert_equal(primary, "JetBrainsMono NFM", "the primary GUI font should be the installed Nerd Font family")

-- The IME is held off unconditionally: it intercepted keys outside actual
-- text composition (e.g. swallowing <Esc> in a terminal buffer), and there is
-- no mode-aware autocmd to turn it back on. `:NeovideIme` is the manual opt-in.
assert_equal(vim.g.neovide_input_ime, false, "IME input should stay off by default")
assert_true(vim.fn.exists(":NeovideIme") == 2, ":NeovideIme should exist to opt in manually")
assert_true(vim.g.neovide_remember_window_size, "window size should be remembered")

for _, lhs in ipairs({ "<C-=>", "<C-->", "<C-0>", "<F11>", "<C-ScrollWheelUp>", "<C-ScrollWheelDown>" }) do
    assert_true(vim.fn.maparg(lhs, "n") ~= "", lhs .. " should be mapped under Neovide")
end

-- Zoom clamps instead of running away. Drive the real mapped callbacks.
local zoom_in = vim.fn.maparg("<C-=>", "n", false, true).callback
local zoom_out = vim.fn.maparg("<C-->", "n", false, true).callback
local zoom_reset = vim.fn.maparg("<C-0>", "n", false, true).callback

assert_true(zoom_in and zoom_out and zoom_reset, "the zoom keys should be backed by callbacks")

zoom_reset()
assert_equal(vim.g.neovide_scale_factor, 1.0, "reset should return to 1.0")

for _ = 1, 100 do
    zoom_in()
end
assert_true(vim.g.neovide_scale_factor <= 3.0, "zooming in should clamp at the maximum")

for _ = 1, 200 do
    zoom_out()
end
assert_true(vim.g.neovide_scale_factor >= 0.5, "zooming out should clamp at the minimum")

zoom_reset()

-- Fullscreen toggles both ways.
local fullscreen = vim.fn.maparg("<F11>", "n", false, true).callback
vim.g.neovide_fullscreen = false
fullscreen()
assert_equal(vim.g.neovide_fullscreen, true, "F11 should enter fullscreen")
fullscreen()
assert_equal(vim.g.neovide_fullscreen, false, "F11 should leave fullscreen")

assert_true(vim.fn.exists(":NeovideZoomReset") == 2, ":NeovideZoomReset should exist")
assert_true(vim.fn.exists(":NeovideFullscreen") == 2, ":NeovideFullscreen should exist")

-- Running twice must not throw.
assert_equal(neovide.setup(), true, "setup() should be safe to call again")

vim.g.neovide = nil

vim.cmd("qa!")
