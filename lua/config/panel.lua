-- A small floating list that can be driven entirely with the mouse: click a row
-- to act on it, click the ✕ to forget it, click the footer to add something.
--
-- Shared by the project list and the recent-file list; see config/projects.lua
-- and config/recent.lua for the specs they pass in.
local M = {}

local REMOVE_MARK = "✕"
local MIN_WIDTH = 48
local MAX_WIDTH = 100
local NAME_WIDTH = 22

local namespace = vim.api.nvim_create_namespace("ClickablePanel")

---@class PanelEntry
---@field id string      value handed back to the callbacks
---@field name string    left column
---@field detail string  right column, elided from the left when long

---@class PanelSpec
---@field kind string                        identifies the panel to the right-click menu
---@field title string
---@field entries fun(): PanelEntry[]
---@field on_open fun(entry: PanelEntry)
---@field on_forget nil|fun(entry: PanelEntry)
---@field add nil|{ label: string, run: fun(refresh: fun()) }
---@field empty string
---@field hint string

local state = {
    buf = nil,
    win = nil,
    spec = nil,
    rows = {}, -- lnum -> { kind = "entry"|"add", entry?, hit_col? }
}

local function is_open()
    return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

function M.close()
    if is_open() then
        vim.api.nvim_win_close(state.win, true)
    end

    state.win = nil
    state.buf = nil
    state.spec = nil
    state.rows = {}
end

---@return string|nil
function M.kind()
    return state.spec and state.spec.kind or nil
end

--- Text helpers --------------------------------------------------------------

---Trim from the left, keeping the tail — the end of a path carries the meaning.
---@param text string
---@param max integer
---@return string
local function elide_left(text, max)
    if max < 2 or vim.fn.strdisplaywidth(text) <= max then
        return text
    end

    return "…" .. vim.fn.strcharpart(text, vim.fn.strchars(text) - (max - 1))
end

---@param text string
---@param max integer
---@return string
local function elide_right(text, max)
    if vim.fn.strdisplaywidth(text) <= max then
        return text
    end

    return vim.fn.strcharpart(text, 0, math.max(max - 1, 1)) .. "…"
end

---@param text string
---@param width integer
---@return string
local function pad_to(text, width)
    return text .. string.rep(" ", math.max(width - vim.fn.strdisplaywidth(text), 0))
end

---Panel width, bounded so the ✕ button always stays on screen no matter how
---deep a path is.
---@param entries PanelEntry[]
---@param add_label string|nil
---@return integer
local function panel_width(entries, add_label)
    local widest = #(add_label or "") + 6

    for _, entry in ipairs(entries) do
        widest = math.max(widest, 4 + NAME_WIDTH + vim.fn.strdisplaywidth(entry.detail or "") + 4)
    end

    local ceiling = math.max(MIN_WIDTH, math.min(vim.o.columns - 8, MAX_WIDTH))

    return math.min(math.max(widest, MIN_WIDTH), ceiling)
end

--- Rendering -----------------------------------------------------------------

local function render()
    if not state.spec or not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        return
    end

    local spec = state.spec
    local entries = spec.entries()
    local width = panel_width(entries, spec.add and spec.add.label)
    local removable = spec.on_forget ~= nil

    local lines, rows, marks = {}, {}, {}

    if vim.tbl_isempty(entries) then
        table.insert(lines, "  " .. spec.empty)
        table.insert(marks, { #lines - 1, 0, -1, "Comment" })
    end

    -- "  <name>  <detail>        ✕" — the marker sits in a fixed column so a
    -- click past it always means "forget", whatever the detail length.
    local detail_room = width - 4 - NAME_WIDTH - 4

    for _, entry in ipairs(entries) do
        local name = pad_to(elide_right(entry.name, NAME_WIDTH), NAME_WIDTH)
        local detail = elide_left(entry.detail or "", detail_room)
        local left = pad_to("  " .. name .. "  " .. detail, removable and (width - 3) or width)
        local text = removable and (left .. REMOVE_MARK) or left

        table.insert(lines, text)
        rows[#lines] = {
            kind = "entry",
            entry = entry,
            hit_col = removable and #left or nil,
        }

        table.insert(marks, { #lines - 1, 2, 2 + #name, "Directory" })
        table.insert(marks, { #lines - 1, 2 + #name, #left, "Comment" })
        if removable then
            table.insert(marks, { #lines - 1, #left, -1, "DiagnosticError" })
        end
    end

    table.insert(lines, string.rep("─", width))
    table.insert(marks, { #lines - 1, 0, -1, "WinSeparator" })

    if spec.add then
        table.insert(lines, "  " .. spec.add.label)
        rows[#lines] = { kind = "add" }
        table.insert(marks, { #lines - 1, 0, -1, "DiagnosticOk" })
    end

    table.insert(lines, "  " .. spec.hint)
    table.insert(marks, { #lines - 1, 0, -1, "Comment" })

    state.rows = rows

    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.bo[state.buf].modifiable = false

    vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
    for _, mark in ipairs(marks) do
        local line, start_col, end_col, group = mark[1], mark[2], mark[3], mark[4]
        pcall(vim.api.nvim_buf_set_extmark, state.buf, namespace, line, start_col, {
            end_col = end_col >= 0 and end_col or #(lines[line + 1] or ""),
            hl_group = group,
        })
    end

    if is_open() then
        -- Re-centre as well as resize; a width change would otherwise leave the
        -- panel hanging off to one side.
        vim.api.nvim_win_set_config(state.win, {
            relative = "editor",
            width = width,
            height = #lines,
            row = math.max(math.floor(vim.o.lines * 0.2), 1),
            col = math.max(math.floor((vim.o.columns - width) / 2), 0),
        })
    end
end

function M.refresh()
    if is_open() then
        render()
    end
end

--- Actions -------------------------------------------------------------------

---The entry on `lnum` (default: the cursor line), or nil on a non-entry row.
---@param lnum integer|nil
---@return PanelEntry|nil
function M.entry_at(lnum)
    if not is_open() then
        return nil
    end

    local row = state.rows[lnum or vim.api.nvim_win_get_cursor(state.win)[1]]

    return row and row.entry or nil
end

---@param action "open"|"forget"|"add"
---@param lnum integer|nil
function M.act(action, lnum)
    local spec = state.spec
    if not spec then
        return
    end

    if action == "add" then
        if spec.add then
            spec.add.run(M.refresh)
        end
        return
    end

    local row = state.rows[lnum or vim.api.nvim_win_get_cursor(0)[1]]
    if not row then
        return
    end

    if row.kind == "add" then
        M.act("add")
        return
    end

    if action == "forget" then
        if spec.on_forget then
            spec.on_forget(row.entry)
            render()
        end
        return
    end

    local entry = row.entry
    M.close()
    spec.on_open(entry)
end

local function on_click()
    local pos = vim.fn.getmousepos()

    if pos.winid ~= state.win then
        return
    end

    local row = state.rows[pos.line]
    if not row then
        return
    end

    vim.api.nvim_win_set_cursor(state.win, { pos.line, 0 })

    if row.kind == "entry" and row.hit_col and pos.column > row.hit_col then
        M.act("forget", pos.line)
    else
        M.act("open", pos.line)
    end
end

--- Opening -------------------------------------------------------------------

---@param spec PanelSpec
function M.open(spec)
    -- Same panel again closes it; a different one replaces it.
    if is_open() then
        local same = M.kind() == spec.kind
        M.close()
        if same then
            return
        end
    end

    state.spec = spec
    state.buf = vim.api.nvim_create_buf(false, true)

    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].buftype = "nofile"
    vim.bo[state.buf].swapfile = false
    vim.bo[state.buf].filetype = "clickable-panel"
    vim.b[state.buf].panel_kind = spec.kind

    -- Size it right from the start; render() re-centres on every redraw.
    local width = panel_width(spec.entries(), spec.add and spec.add.label)

    state.win = vim.api.nvim_open_win(state.buf, true, {
        relative = "editor",
        width = width,
        height = 10,
        row = math.max(math.floor(vim.o.lines * 0.2), 1),
        col = math.max(math.floor((vim.o.columns - width) / 2), 0),
        style = "minimal",
        border = "rounded",
        title = spec.title,
        title_pos = "center",
    })

    vim.wo[state.win].cursorline = true
    vim.wo[state.win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"

    render()

    local opts = { buffer = state.buf, nowait = true, silent = true }
    local map = vim.keymap.set

    -- <LeftMouse> stays unmapped so Neovim still does its own focus/cursor
    -- handling on press, and so <RightMouse> can open the context menu.
    map("n", "<LeftRelease>", on_click, vim.tbl_extend("force", opts, { desc = "Act on the clicked row" }))
    map("n", "<2-LeftMouse>", on_click, vim.tbl_extend("force", opts, { desc = "Act on the clicked row" }))
    map("n", "<CR>", function()
        M.act("open")
    end, vim.tbl_extend("force", opts, { desc = "Open" }))
    map("n", "d", function()
        M.act("forget")
    end, vim.tbl_extend("force", opts, { desc = "Forget" }))
    map("n", "a", function()
        M.act("add")
    end, vim.tbl_extend("force", opts, { desc = "Add" }))
    map("n", "q", M.close, vim.tbl_extend("force", opts, { desc = "Close" }))
    map("n", "<Esc>", M.close, vim.tbl_extend("force", opts, { desc = "Close" }))

    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = state.buf,
        once = true,
        callback = function()
            vim.schedule(M.close)
        end,
    })
end

return M
