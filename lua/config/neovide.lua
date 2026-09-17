-- Neovide-only settings. Everything here is a no-op under the terminal UI, so
-- the module short-circuits unless `vim.g.neovide` is set.
--
-- The `vim.g.neovide_*` names below were checked against the installed Neovide
-- build; unknown names are silently ignored by Neovide, but sticking to the
-- real ones keeps this honest.
local M = {}

-- Font families as Windows reports them. Nerd Fonts v3 installs the
-- "windows compatible" variants as `JetBrainsMono NF` / `NFM` / `NFP`, not as
-- `JetBrainsMono Nerd Font` — asking for the latter silently falls back to a
-- font with no icons. `NFM` keeps every glyph single-width, which is what
-- neo-tree and bufferline assume.
M.font = "JetBrainsMono NFM,JetBrains Mono,Cascadia Mono:h12"

local min_scale, max_scale = 0.5, 3.0

---@param delta number
local function scale_by(delta)
    local current = vim.g.neovide_scale_factor or 1.0
    vim.g.neovide_scale_factor = math.min(max_scale, math.max(min_scale, current + delta))
end

local function reset_scale()
    vim.g.neovide_scale_factor = 1.0
end

local function toggle_fullscreen()
    vim.g.neovide_fullscreen = not vim.g.neovide_fullscreen
end

---@return boolean true when Neovide is the UI and the settings were applied
function M.setup()
    if not vim.g.neovide then
        return false
    end

    vim.o.guifont = M.font

    -- Window
    vim.g.neovide_remember_window_size = true
    vim.g.neovide_remember_window_position = true
    vim.g.neovide_theme = "dark" -- matches kanagawa wave; avoids a white flash
    vim.g.neovide_padding_top = 4
    vim.g.neovide_padding_bottom = 0
    vim.g.neovide_padding_left = 4
    vim.g.neovide_padding_right = 0

    -- Input. While `neovide_input_ime` is on, keys go through the Windows IME
    -- first, and the IME swallows <Esc> to cancel composition — so <Esc> never
    -- reaches Neovim and the mapping that leaves a toggleterm float looks dead,
    -- even though the mapping is there. Clicking another window appeared to fix
    -- it only because changing focus resets the IME.
    --
    -- So the IME is on only where text is actually composed. A shell takes
    -- ASCII, so terminal mode counts as "off" and <Esc> gets through; use
    -- `:NeovideIme` when a terminal really does need Vietnamese input.
    vim.g.neovide_input_ime = false
    vim.g.neovide_hide_mouse_when_typing = true

    local ime = vim.api.nvim_create_augroup("neovide_ime", { clear = true })

    vim.api.nvim_create_autocmd({ "InsertEnter", "CmdlineEnter" }, {
        group = ime,
        desc = "Neovide: hand keys to the IME while composing text",
        callback = function()
            vim.g.neovide_input_ime = true
        end,
    })

    -- `TermEnter` is terminal mode, which Neovim does not report as insert.
    vim.api.nvim_create_autocmd({ "InsertLeave", "CmdlineLeave", "TermEnter" }, {
        group = ime,
        desc = "Neovide: take keys back from the IME so <Esc> arrives",
        callback = function()
            vim.g.neovide_input_ime = false
        end,
    })

    -- Rendering. Idle throttling keeps a background window from burning GPU.
    vim.g.neovide_refresh_rate = 60
    vim.g.neovide_refresh_rate_idle = 5

    -- Cursor: a short trail reads as responsive without feeling laggy.
    vim.g.neovide_cursor_animation_length = 0.05
    vim.g.neovide_cursor_short_animation_length = 0.03
    vim.g.neovide_cursor_trail_size = 0.3
    vim.g.neovide_cursor_animate_in_insert_mode = false
    vim.g.neovide_cursor_animate_command_line = false
    vim.g.neovide_cursor_smooth_blink = true
    vim.g.neovide_cursor_unfocused_outline_width = 0.1

    local map = vim.keymap.set

    -- Zoom, the way every GUI editor does it.
    map({ "n", "v", "i" }, "<C-=>", function()
        scale_by(0.1)
    end, { desc = "Neovide: zoom in" })
    map({ "n", "v", "i" }, "<C-+>", function()
        scale_by(0.1)
    end, { desc = "Neovide: zoom in" })
    map({ "n", "v", "i" }, "<C-->", function()
        scale_by(-0.1)
    end, { desc = "Neovide: zoom out" })
    map({ "n", "v", "i" }, "<C-0>", reset_scale, { desc = "Neovide: reset zoom" })
    map({ "n", "v", "i" }, "<C-ScrollWheelUp>", function()
        scale_by(0.1)
    end, { desc = "Neovide: zoom in" })
    map({ "n", "v", "i" }, "<C-ScrollWheelDown>", function()
        scale_by(-0.1)
    end, { desc = "Neovide: zoom out" })

    map({ "n", "v", "i" }, "<F11>", toggle_fullscreen, { desc = "Neovide: toggle fullscreen" })

    vim.api.nvim_create_user_command("NeovideIme", function()
        vim.g.neovide_input_ime = not vim.g.neovide_input_ime
        vim.notify("Neovide IME " .. (vim.g.neovide_input_ime and "on" or "off"))
    end, { desc = "Toggle the Neovide IME for the current mode" })

    vim.api.nvim_create_user_command("NeovideZoomReset", reset_scale, { desc = "Reset the Neovide zoom level" })
    vim.api.nvim_create_user_command("NeovideFullscreen", toggle_fullscreen, { desc = "Toggle Neovide fullscreen" })

    return true
end

return M
