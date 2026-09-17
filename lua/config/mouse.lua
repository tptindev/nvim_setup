-- Mouse support: a context-aware right-click menu for editor buffers, the
-- file explorer and the buffer tabline, plus the click bindings that go with it.
--
-- The menu is rebuilt on every `MenuPopup` so it can differ per buffer; building
-- it is a handful of `:menu` commands, which is cheap enough to do per click.
local M = {}

local function has_lsp()
    return vim.lsp.get_clients({ bufnr = 0 })[1] ~= nil
end

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.INFO)
end

---Absolute path of the current buffer, or nil for scratch/terminal buffers.
---@return string|nil
local function buffer_path()
    if vim.bo.buftype ~= "" then
        return nil
    end

    local name = vim.api.nvim_buf_get_name(0)
    return name ~= "" and name or nil
end

---Reveal `path` in the Windows file explorer, selecting it when it is a file.
---@param path string
function M.reveal(path)
    if not path or path == "" then
        notify("Nothing to reveal", vim.log.levels.WARN)
        return
    end

    local native = vim.fs.normalize(path):gsub("/", "\\")

    if vim.fn.has("win32") == 1 then
        -- explorer.exe exits non-zero even when it succeeds, so ignore the result.
        vim.system({ "explorer.exe", "/select,", native }, { detach = true })
        return
    end

    vim.ui.open(vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path))
end

---@param path string|nil
---@param modifier string
local function yank_path(path, modifier)
    if not path then
        notify("This buffer has no file path", vim.log.levels.WARN)
        return
    end

    local value = vim.fn.fnamemodify(path, modifier)
    vim.fn.setreg("+", value)
    notify("Copied: " .. value)
end

function M.copy_path()
    yank_path(buffer_path(), ":p")
end

function M.copy_relative_path()
    yank_path(buffer_path(), ":.")
end

function M.reveal_buffer()
    M.reveal(buffer_path() or vim.fn.getcwd())
end

---Open a floating terminal in the directory that owns `path`.
---@param path string|nil
function M.terminal_here(path)
    local dir = path or buffer_path()
    dir = dir and (vim.fn.isdirectory(dir) == 1 and dir or vim.fs.dirname(dir)) or vim.fn.getcwd()

    local ok, err = pcall(vim.cmd, "ToggleTerm dir=" .. vim.fn.fnameescape(dir))
    if not ok then
        notify("Could not open a terminal: " .. tostring(err), vim.log.levels.WARN)
    end
end

--- Neo-tree ------------------------------------------------------------------

---@return table|nil state, table|nil node
local function tree_context()
    local ok, manager = pcall(require, "neo-tree.sources.manager")
    if not ok then
        return nil, nil
    end

    local state = manager.get_state_for_window(vim.api.nvim_get_current_win())
    if not state or not state.tree then
        return nil, nil
    end

    return state, state.tree:get_node()
end

---Run a neo-tree filesystem command against the node under the cursor.
---@param name string
function M.tree(name)
    local state = tree_context()
    if not state then
        notify("Not inside the file explorer", vim.log.levels.WARN)
        return
    end

    local commands = require("neo-tree.sources.filesystem.commands")
    local command = commands[name]

    if type(command) ~= "function" then
        notify("Unknown explorer command: " .. name, vim.log.levels.ERROR)
        return
    end

    command(state)
end

---@return string|nil
local function tree_path()
    local _, node = tree_context()
    return node and node:get_id() or nil
end

function M.tree_copy_path()
    yank_path(tree_path(), ":p")
end

function M.tree_copy_relative_path()
    yank_path(tree_path(), ":.")
end

function M.tree_reveal()
    M.reveal(tree_path() or vim.fn.getcwd())
end

function M.tree_terminal_here()
    M.terminal_here(tree_path())
end

---Directory that the node under the cursor lives in (the node itself when it is
---a directory).
---@return string|nil
local function tree_directory()
    local path = tree_path()
    if not path then
        return nil
    end

    if vim.fn.isdirectory(path) ~= 1 then
        path = vim.fs.dirname(path)
    end

    return path
end

---Open the directory under the cursor as a project.
function M.tree_open_project()
    local path = tree_directory()
    if path then
        require("config.projects").open(path)
    end
end

---Add the directory under the cursor to the project list without switching.
function M.tree_add_project()
    local path = tree_directory()
    if not path then
        return
    end

    local projects = require("config.projects")
    local added = projects.add(path)

    if added then
        notify("Added project: " .. vim.fn.fnamemodify(added, ":~"))
        projects.refresh_panel()
    else
        notify("Not a usable project directory: " .. path, vim.log.levels.WARN)
    end
end

---Drop the directory under the cursor from the project list. Files are untouched.
function M.tree_forget_project()
    local path = tree_directory()
    if not path then
        return
    end

    local projects = require("config.projects")
    projects.remove(path)
    notify("Forgot project: " .. vim.fn.fnamemodify(path, ":~"))
    projects.refresh_panel()
end

--- Project actions on the current buffer ------------------------------------

function M.add_current_project()
    local projects = require("config.projects")
    local root = projects.detect() or projects.current()
    local added = projects.add(root)

    if added then
        notify("Added project: " .. vim.fn.fnamemodify(added, ":~"))
        projects.refresh_panel()
    else
        notify("Not a usable project directory: " .. root, vim.log.levels.WARN)
    end
end

function M.forget_current_project()
    local projects = require("config.projects")
    local root = projects.detect() or projects.current()
    projects.remove(root)
    notify("Forgot project: " .. vim.fn.fnamemodify(root, ":~"))
    projects.refresh_panel()
end

--- Clickable panels ----------------------------------------------------------

---Reveal whatever the cursor is on inside an open panel. The row text elides
---long paths, so ask the panel for the entry rather than parsing the line.
function M.panel_reveal()
    local entry = require("config.panel").entry_at()

    if not entry then
        notify("Nothing to reveal", vim.log.levels.WARN)
        return
    end

    M.reveal(entry.id)
end

--- Menus ---------------------------------------------------------------------

local function clear_menu()
    vim.cmd("silent! aunmenu PopUp")
end

local function build_editor_menu()
    vim.cmd([[
        vnoremenu PopUp.Cut                      "+x
        vnoremenu PopUp.Copy                     "+y
        anoremenu PopUp.Paste                    "+gP
        vnoremenu PopUp.Paste                    "+P
        vnoremenu PopUp.Delete                   "_x
        nnoremenu PopUp.Select\ All              ggVG
        vnoremenu PopUp.Select\ All              gg0oG$
        inoremenu PopUp.Select\ All              <C-Home><C-O>VG
        anoremenu PopUp.-sep1-                   <Nop>
        anoremenu PopUp.Go\ to\ Definition       <Cmd>lua vim.lsp.buf.definition()<CR>
        anoremenu PopUp.Find\ References         <Cmd>lua require('fzf-lua').lsp_references()<CR>
        anoremenu PopUp.Rename\ Symbol           <Cmd>lua vim.lsp.buf.rename()<CR>
        anoremenu PopUp.Code\ Action             <Cmd>lua vim.lsp.buf.code_action()<CR>
        anoremenu PopUp.Format\ Buffer           <Cmd>lua require('conform').format({ async = true, lsp_format = 'fallback' })<CR>
        anoremenu PopUp.-sep2-                   <Nop>
        anoremenu PopUp.Show\ Diagnostics        <Cmd>lua vim.diagnostic.open_float()<CR>
        anoremenu PopUp.Inspect\ Highlight       <Cmd>Inspect<CR>
        anoremenu PopUp.-sep3-                   <Nop>
        anoremenu PopUp.Copy\ Full\ Path         <Cmd>lua require('config.mouse').copy_path()<CR>
        anoremenu PopUp.Copy\ Relative\ Path     <Cmd>lua require('config.mouse').copy_relative_path()<CR>
        anoremenu PopUp.Reveal\ in\ Explorer     <Cmd>lua require('config.mouse').reveal_buffer()<CR>
        anoremenu PopUp.Terminal\ Here           <Cmd>lua require('config.mouse').terminal_here()<CR>
        anoremenu PopUp.-sep4-                   <Nop>
        anoremenu PopUp.Projects\.\.\.           <Cmd>ProjectPanel<CR>
        anoremenu PopUp.Recent\ Files\.\.\.       <Cmd>RecentFiles<CR>
        anoremenu PopUp.Add\ This\ Project       <Cmd>lua require('config.mouse').add_current_project()<CR>
        anoremenu PopUp.Forget\ This\ Project    <Cmd>lua require('config.mouse').forget_current_project()<CR>
    ]])

    if not has_lsp() then
        vim.cmd([[
            amenu disable PopUp.Go\ to\ Definition
            amenu disable PopUp.Find\ References
            amenu disable PopUp.Rename\ Symbol
            amenu disable PopUp.Code\ Action
        ]])
    end

    if vim.tbl_isempty(vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })) then
        vim.cmd([[amenu disable PopUp.Show\ Diagnostics]])
    end

    if not buffer_path() then
        vim.cmd([[
            amenu disable PopUp.Copy\ Full\ Path
            amenu disable PopUp.Copy\ Relative\ Path
        ]])
    end
end

local function build_tree_menu()
    vim.cmd([[
        anoremenu PopUp.Open                     <Cmd>lua require('config.mouse').tree('open')<CR>
        anoremenu PopUp.Open\ in\ Split          <Cmd>lua require('config.mouse').tree('open_split')<CR>
        anoremenu PopUp.Open\ in\ Vertical\ Split <Cmd>lua require('config.mouse').tree('open_vsplit')<CR>
        anoremenu PopUp.Open\ in\ New\ Tab       <Cmd>lua require('config.mouse').tree('open_tabnew')<CR>
        anoremenu PopUp.-sep1-                   <Nop>
        anoremenu PopUp.New\ File                <Cmd>lua require('config.mouse').tree('add')<CR>
        anoremenu PopUp.New\ Folder              <Cmd>lua require('config.mouse').tree('add_directory')<CR>
        anoremenu PopUp.Rename                   <Cmd>lua require('config.mouse').tree('rename')<CR>
        anoremenu PopUp.-sep2-                   <Nop>
        anoremenu PopUp.Cut                      <Cmd>lua require('config.mouse').tree('cut_to_clipboard')<CR>
        anoremenu PopUp.Copy                     <Cmd>lua require('config.mouse').tree('copy_to_clipboard')<CR>
        anoremenu PopUp.Paste                    <Cmd>lua require('config.mouse').tree('paste_from_clipboard')<CR>
        anoremenu PopUp.Duplicate\.\.\.          <Cmd>lua require('config.mouse').tree('copy')<CR>
        anoremenu PopUp.Move\.\.\.               <Cmd>lua require('config.mouse').tree('move')<CR>
        anoremenu PopUp.-sep3-                   <Nop>
        anoremenu PopUp.Delete                   <Cmd>lua require('config.mouse').tree('delete')<CR>
        anoremenu PopUp.Move\ to\ Recycle\ Bin   <Cmd>lua require('config.mouse').tree('trash')<CR>
        anoremenu PopUp.-sep4-                   <Nop>
        anoremenu PopUp.Copy\ Full\ Path         <Cmd>lua require('config.mouse').tree_copy_path()<CR>
        anoremenu PopUp.Copy\ Relative\ Path     <Cmd>lua require('config.mouse').tree_copy_relative_path()<CR>
        anoremenu PopUp.Reveal\ in\ Explorer     <Cmd>lua require('config.mouse').tree_reveal()<CR>
        anoremenu PopUp.Terminal\ Here           <Cmd>lua require('config.mouse').tree_terminal_here()<CR>
        anoremenu PopUp.-sep5-                   <Nop>
        anoremenu PopUp.Open\ as\ Project        <Cmd>lua require('config.mouse').tree_open_project()<CR>
        anoremenu PopUp.Add\ as\ Project         <Cmd>lua require('config.mouse').tree_add_project()<CR>
        anoremenu PopUp.Forget\ Project          <Cmd>lua require('config.mouse').tree_forget_project()<CR>
        anoremenu PopUp.Projects\.\.\.           <Cmd>ProjectPanel<CR>
        anoremenu PopUp.Set\ as\ Explorer\ Root  <Cmd>lua require('config.mouse').tree('set_root')<CR>
        anoremenu PopUp.Refresh                  <Cmd>lua require('config.mouse').tree('refresh')<CR>
    ]])

    local _, node = tree_context()
    if node and node.type == "directory" then
        vim.cmd([[
            amenu disable PopUp.Open\ in\ Split
            amenu disable PopUp.Open\ in\ Vertical\ Split
            amenu disable PopUp.Open\ in\ New\ Tab
        ]])
    else
        vim.cmd([[amenu disable PopUp.Open\ as\ Project]])
    end
end

-- The clickable panels get their own short menu; the editor menu makes no sense
-- on a list of paths.
---@param kind string
local function build_panel_menu(kind)
    local is_projects = kind == "projects"

    -- Long brackets, so the backslashes that :menu needs survive verbatim.
    local open_label = is_projects and [[Open\ Project]] or [[Open\ File]]
    local add_label = is_projects and [[Add\ Folder\.\.\.]] or [[Open\ File\.\.\.]]

    vim.cmd(([[
        anoremenu PopUp.%s <Cmd>lua require('config.panel').act('open')<CR>
        anoremenu PopUp.Forget <Cmd>lua require('config.panel').act('forget')<CR>
        anoremenu PopUp.Reveal\ in\ Explorer <Cmd>lua require('config.mouse').panel_reveal()<CR>
        anoremenu PopUp.-sep1- <Nop>
        anoremenu PopUp.%s <Cmd>lua require('config.panel').act('add')<CR>
        anoremenu PopUp.Close <Cmd>lua require('config.panel').close()<CR>
    ]]):format(open_label, add_label))
end

--- Buffer tabs ---------------------------------------------------------------

---Right-click menu for a bufferline tab. `bufnr` comes from bufferline.
---@param bufnr integer
function M.tab_menu(bufnr)
    local buffers = require("config.buffers")

    local items = {
        {
            "Close",
            function()
                buffers.close(bufnr)
            end,
        },
        {
            "Close Others",
            function()
                for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
                    if info.bufnr ~= bufnr then
                        buffers.close(info.bufnr)
                    end
                end
            end,
        },
        {
            "Copy Full Path",
            function()
                yank_path(vim.api.nvim_buf_get_name(bufnr), ":p")
            end,
        },
        {
            "Reveal in Explorer",
            function()
                M.reveal(vim.api.nvim_buf_get_name(bufnr))
            end,
        },
    }

    local labels = vim.tbl_map(function(item)
        return item[1]
    end, items)

    vim.ui.select(labels, { prompt = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t") }, function(choice)
        for _, item in ipairs(items) do
            if item[1] == choice then
                item[2]()
                return
            end
        end
    end)
end

--- Pointer affordances -------------------------------------------------------

-- VSCode-style pointer behaviour: resting on a symbol shows its documentation,
-- Ctrl+click jumps to its definition.
--
-- `mousemoveevent` (options.lua) turns pointer motion into `<MouseMove>` keys.
-- bufferline already maps that key for its own tab hover and re-emits it from
-- an `<expr>` mapping, and a plain re-map is not run again, so whoever maps it
-- last owns the key. This chains onto the handler already bound instead of
-- replacing it, and installs after `VeryLazy` so bufferline is bound first.

local hover = {
    delay = 350,
    -- Bumped on every pointer move so a stale timer cannot fire late.
    token = 0,
    win = nil,
    -- Buffer cells the open float describes, so drifting within the symbol
    -- keeps it up instead of flickering it shut and open again.
    range = nil,
}

local function hover_close()
    if hover.win and vim.api.nvim_win_is_valid(hover.win) then
        pcall(vim.api.nvim_win_close, hover.win, true)
    end

    hover.win = nil
    hover.range = nil
end

---@param text string
---@param byte_col integer 0-based byte offset
---@param encoding string
---@return integer
local function utf_character(text, byte_col, encoding)
    local ok, index = pcall(vim.str_utfindex, text, encoding, byte_col, false)
    return ok and index or byte_col
end

---The hover range as 1-based inclusive columns, or nil when the server gave no
---range, gave a multi-line one, or the offsets do not convert.
---@return table|nil
local function range_cells(buf, winid, range, encoding)
    if not range or not range.start or range.start.line ~= range["end"].line then
        return nil
    end

    local lnum = range.start.line + 1
    local text = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
    if not text then
        return nil
    end

    local ok_from, from = pcall(vim.str_byteindex, text, encoding, range.start.character, false)
    local ok_to, to = pcall(vim.str_byteindex, text, encoding, range["end"].character, false)

    if not (ok_from and ok_to) then
        return nil
    end

    return { winid = winid, line = lnum, from = from + 1, to = to }
end

---@param pos table result of `getmousepos()`
local function hover_show(pos)
    if vim.fn.pumvisible() == 1 or not vim.api.nvim_win_is_valid(pos.winid) then
        return
    end

    local buf = vim.api.nvim_win_get_buf(pos.winid)
    if vim.bo[buf].buftype ~= "" then
        return
    end

    local client = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/hover" })[1]
    if not client then
        return
    end

    local text = vim.api.nvim_buf_get_lines(buf, pos.line - 1, pos.line, false)[1]
    if not text or text == "" then
        return
    end

    -- Past the end of the line the pointer is in the margin, and whitespace
    -- never has documentation — asking anyway just flashes an empty popup.
    local byte_col = pos.column - 1
    if byte_col >= #text or text:sub(pos.column, pos.column):match("%s") then
        return
    end

    local encoding = client.offset_encoding or "utf-16"

    client:request("textDocument/hover", {
        textDocument = vim.lsp.util.make_text_document_params(buf),
        position = { line = pos.line - 1, character = utf_character(text, byte_col, encoding) },
    }, function(err, result)
        if err or not result or not result.contents then
            return
        end

        local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
        if vim.tbl_isempty(lines) then
            return
        end

        -- The server answers asynchronously; the pointer may have moved on,
        -- and anchoring to `mouse` would then place the float somewhere else.
        local ok, current = pcall(vim.fn.getmousepos)
        if not ok or current.winid ~= pos.winid or current.line ~= pos.line or current.column ~= pos.column then
            return
        end

        hover_close()

        local _, win = vim.lsp.util.open_floating_preview(lines, "markdown", {
            relative = "mouse",
            border = "rounded",
            max_width = 80,
            max_height = 20,
            focus = false,
        })

        hover.win = win
        hover.range = range_cells(buf, pos.winid, result.range, encoding)
    end, buf)
end

local function hover_on_move()
    local ok, pos = pcall(vim.fn.getmousepos)
    if not ok then
        return
    end

    -- Let the pointer rest inside the popup — moving into it to scroll must not
    -- tear it down — and drift within the symbol it describes.
    if hover.win and pos.winid == hover.win then
        return
    end

    local range = hover.range
    if
        range
        and range.winid == pos.winid
        and range.line == pos.line
        and pos.column >= range.from
        and pos.column <= range.to
    then
        return
    end

    hover_close()

    hover.token = hover.token + 1
    local token = hover.token

    vim.defer_fn(function()
        if token == hover.token then
            hover_show(pos)
        end
    end, hover.delay)
end

local hover_installed = false

---Bind `<MouseMove>` for hover docs, chaining onto any existing handler.
function M.enable_hover()
    -- A second call would capture this very mapping as the one to forward to
    -- and recurse forever.
    if hover_installed then
        return
    end

    hover_installed = true

    local existing = vim.fn.maparg("<MouseMove>", "n", false, true)
    local forward = type(existing) == "table" and existing.callback or nil

    vim.keymap.set({ "n", "i" }, "<MouseMove>", function()
        if forward then
            pcall(forward)
        end

        hover_on_move()

        return "<MouseMove>"
    end, { expr = true, desc = "LSP hover under the pointer" })
end

---Jump to the definition of whatever the pointer is over.
function M.goto_definition_at_mouse()
    local ok, pos = pcall(vim.fn.getmousepos)
    if not ok or pos.winid == 0 or not vim.api.nvim_win_is_valid(pos.winid) then
        return
    end

    hover_close()

    vim.api.nvim_set_current_win(pos.winid)
    pcall(vim.api.nvim_win_set_cursor, pos.winid, { pos.line, math.max(0, pos.column - 1) })

    -- Land in normal mode: the point of the jump is to read the definition.
    if vim.fn.mode():match("^i") then
        vim.cmd("stopinsert")
    end

    if not has_lsp() then
        notify("No language server for this buffer", vim.log.levels.WARN)
        return
    end

    vim.lsp.buf.definition()
end

--- Setup ---------------------------------------------------------------------

local is_setup = false

function M.setup()
    if is_setup then
        return
    end

    is_setup = true

    -- Neovim's built-in handler enables/disables menu entries that this config
    -- replaces, which would error on every right-click. Drop it.
    pcall(vim.api.nvim_clear_autocmds, { group = "nvim.popupmenu" })

    local group = vim.api.nvim_create_augroup("MouseContextMenu", { clear = true })

    -- Bind hover on the first `LspAttach` rather than at startup: bufferline
    -- claims `<MouseMove>` when it loads on `VeryLazy`, and whoever binds last
    -- owns the key, so waiting for an LSP puts this after it without depending
    -- on plugin load order. Nothing to hover before a server attaches anyway.
    vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        once = true,
        desc = "Bind pointer hover once a language server is available",
        callback = function()
            M.enable_hover()
        end,
    })

    vim.api.nvim_create_autocmd("MenuPopup", {
        group = group,
        pattern = "*",
        desc = "Build the right-click menu for the current buffer",
        callback = function()
            clear_menu()

            if vim.b.panel_kind then
                build_panel_menu(vim.b.panel_kind)
            elseif vim.bo.filetype == "neo-tree" then
                build_tree_menu()
            else
                build_editor_menu()
            end
        end,
    })
end

return M
