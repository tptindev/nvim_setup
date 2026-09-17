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

    vim.api.nvim_create_autocmd("MenuPopup", {
        group = vim.api.nvim_create_augroup("MouseContextMenu", { clear = true }),
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
