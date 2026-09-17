-- Project management: root detection, a persistent recent-project list,
-- and one session per project.
local M = {}

local uv = vim.uv or vim.loop

-- `vim.g.projects_data_dir` lets tests point the store somewhere disposable.
local function data_dir()
    return vim.g.projects_data_dir or vim.fs.joinpath(vim.fn.stdpath("data"), "projects")
end

local function list_file()
    return vim.fs.joinpath(data_dir(), "projects.json")
end

local function session_dir()
    return vim.fs.joinpath(data_dir(), "sessions")
end

-- Ordered from most to least specific: vim.fs.root() returns the first marker
-- it finds while walking up, so build/tooling markers win over a bare .git.
M.root_markers = {
    "CMakePresets.json",
    "CMakeLists.txt",
    "compile_commands.json",
    ".clangd",
    "meson.build",
    "Makefile",
    ".luarc.json",
    ".git",
}

local function mkdirp(path)
    vim.fn.mkdir(path, "p")
end

local function read_file(path)
    local fd = uv.fs_open(path, "r", 438)
    if not fd then
        return nil
    end

    local stat = uv.fs_fstat(fd)
    local data = stat and uv.fs_read(fd, stat.size, 0) or nil
    uv.fs_close(fd)

    return data
end

local function write_file(path, data)
    mkdirp(vim.fs.dirname(path))

    local fd = uv.fs_open(path, "w", 420)
    if not fd then
        return false
    end

    uv.fs_write(fd, data, 0)
    uv.fs_close(fd)

    return true
end

local function is_directory(path)
    local stat = path and uv.fs_stat(path)
    return stat ~= nil and stat.type == "directory"
end

local function strip_trailing_slash(path)
    if #path > 1 then
        return (path:gsub("/$", ""))
    end
    return path
end

---Normalized absolute path, or nil when the directory does not exist.
---@param path string|nil
---@return string|nil
local function canonical(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    local expanded = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
    local normalized = strip_trailing_slash(vim.fs.normalize(expanded))

    return is_directory(normalized) and normalized or nil
end

-- The home directory and Neovim's own data dir are never useful as projects.
local ignored_roots = {}
do
    local home = canonical(vim.fn.expand("~"))
    local data = canonical(vim.fn.stdpath("data"))

    if home then
        ignored_roots[home] = true
    end
    if data then
        ignored_roots[data] = true
    end
end

---Detect the project root that owns `path` (defaults to the current buffer).
---@param path string|nil
---@return string|nil
function M.detect(path)
    local start = path

    if not start then
        local name = vim.api.nvim_buf_get_name(0)
        start = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
    end

    if not is_directory(start) then
        start = vim.fs.dirname(start)
    end

    local found = vim.fs.root(start, M.root_markers)

    return found and strip_trailing_slash(vim.fs.normalize(found)) or nil
end

---@return string[]
function M.list()
    local data = read_file(list_file())
    if not data or data == "" then
        return {}
    end

    local ok, decoded = pcall(vim.json.decode, data)
    if not ok or type(decoded) ~= "table" then
        return {}
    end

    local projects, seen = {}, {}
    for _, entry in ipairs(decoded) do
        local path = canonical(entry)
        if path and not seen[path] then
            seen[path] = true
            table.insert(projects, path)
        end
    end

    return projects
end

local function persist(projects)
    write_file(list_file(), vim.json.encode(projects))
end

---Record `path` as the most recently used project.
---@param path string
---@return string|nil
function M.add(path)
    local root = canonical(path)
    if not root or ignored_roots[root] then
        return nil
    end

    local projects = { root }
    for _, existing in ipairs(M.list()) do
        if existing ~= root then
            table.insert(projects, existing)
        end
    end

    -- Keep the list bounded; older entries fall off the end.
    while #projects > 30 do
        table.remove(projects)
    end

    persist(projects)

    return root
end

---@param path string
function M.remove(path)
    local root = canonical(path) or strip_trailing_slash(vim.fs.normalize(path))
    local projects = {}

    for _, existing in ipairs(M.list()) do
        if existing ~= root then
            table.insert(projects, existing)
        end
    end

    persist(projects)
end

---Change the global working directory. Kept dependency-free: tests call this
---with `-u NONE`.
---@param path string
---@return string
function M.set_root(path)
    local normalized = strip_trailing_slash(vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p")))
    vim.cmd("cd " .. vim.fn.fnameescape(normalized))
    return normalized
end

---@return string
function M.current()
    return strip_trailing_slash(vim.fs.normalize(vim.fn.getcwd()))
end

local function session_file(root)
    local slug = vim.fs.normalize(root):gsub("[^%w]", "_")
    return vim.fs.joinpath(session_dir(), slug .. ".vim")
end

-- Floating/scratch windows and terminals do not survive :mksession cleanly, so
-- drop them before writing and let the plugins re-create their own state.
local function close_transient_windows()
    pcall(vim.cmd, "Neotree close")

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, config = pcall(vim.api.nvim_win_get_config, win)
        if ok and config.relative ~= "" and #vim.api.nvim_list_wins() > 1 then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end
end

local function has_real_buffer()
    for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        if vim.api.nvim_buf_is_valid(info.bufnr)
            and vim.bo[info.bufnr].buftype == ""
            and vim.api.nvim_buf_get_name(info.bufnr) ~= ""
        then
            return true
        end
    end

    return false
end

---Write the session for `root` (defaults to the cwd). No-op for an empty editor.
---@param root string|nil
---@return boolean
function M.save_session(root)
    root = root or M.current()

    if not has_real_buffer() then
        return false
    end

    close_transient_windows()
    mkdirp(session_dir())

    local target = session_file(root)
    local ok, err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(target))

    if not ok then
        vim.notify("Could not save session: " .. tostring(err), vim.log.levels.WARN)
    end

    return ok
end

---@param root string|nil
---@return boolean
function M.load_session(root)
    root = root or M.current()

    local target = session_file(root)
    if vim.fn.filereadable(target) ~= 1 then
        return false
    end

    local ok, err = pcall(vim.cmd, "silent! source " .. vim.fn.fnameescape(target))
    if not ok then
        vim.notify("Could not load session: " .. tostring(err), vim.log.levels.WARN)
        return false
    end

    return true
end

---@param root string|nil
function M.delete_session(root)
    local target = session_file(root or M.current())
    if vim.fn.filereadable(target) == 1 then
        uv.fs_unlink(target)
    end
end

local function reset_editor()
    vim.cmd("silent! %bwipeout!")
    vim.cmd("enew")
end

---Switch to `path`: persist the current session, cd, then restore the target
---session (or open the explorer when the project has none yet).
---@param path string
---@param opts { session?: boolean }|nil
---@return boolean
function M.open(path, opts)
    opts = opts or {}

    local root = canonical(path)
    if not root then
        vim.notify("Not a directory: " .. tostring(path), vim.log.levels.WARN)
        return false
    end

    local use_session = opts.session ~= false

    if use_session then
        M.save_session()
    end

    reset_editor()
    M.set_root(root)
    M.add(root)

    local restored = use_session and M.load_session(root) or false

    if not restored then
        vim.schedule(function()
            pcall(vim.cmd, "Neotree close")
            pcall(vim.cmd, "Neotree show left dir=" .. vim.fn.fnameescape(root))
        end)
    end

    vim.notify("Project: " .. vim.fn.fnamemodify(root, ":~"), vim.log.levels.INFO)

    return true
end

---cd to the project root that owns the current buffer.
---@return string|nil
function M.cd_to_root()
    local root = M.detect()
    if not root then
        vim.notify("No project root found for this buffer", vim.log.levels.WARN)
        return nil
    end

    M.set_root(root)
    M.add(root)
    vim.notify("Project root: " .. vim.fn.fnamemodify(root, ":~"), vim.log.levels.INFO)

    return root
end

local function prompt_for_directory(callback)
    vim.ui.input({ prompt = "Project directory: ", default = M.current(), completion = "dir" }, function(input)
        if input and input ~= "" then
            callback(input)
        end
    end)
end

---Pick a project from the recent list. `ctrl-d` removes an entry (fzf-lua only).
function M.pick()
    local projects = M.list()

    if vim.tbl_isempty(projects) then
        vim.notify("No projects recorded yet — pick a directory to start one.", vim.log.levels.INFO)
        prompt_for_directory(function(path)
            M.open(path)
        end)
        return
    end

    local display = {}
    for _, root in ipairs(projects) do
        table.insert(display, vim.fn.fnamemodify(root, ":~"))
    end

    local function resolve(choice)
        for index, label in ipairs(display) do
            if label == choice then
                return projects[index]
            end
        end
        return choice
    end

    local ok_fzf, fzf = pcall(require, "fzf-lua")
    if ok_fzf then
        fzf.fzf_exec(display, {
            prompt = "Projects> ",
            winopts = { preview = { hidden = true } },
            actions = {
                ["default"] = function(selected)
                    local choice = selected and selected[1]
                    if choice then
                        M.open(resolve(choice))
                    end
                end,
                ["ctrl-d"] = function(selected)
                    local choice = selected and selected[1]
                    if choice then
                        M.remove(resolve(choice))
                        vim.notify("Removed project: " .. choice, vim.log.levels.INFO)
                    end
                end,
            },
        })
        return
    end

    vim.ui.select(display, { prompt = "Projects" }, function(choice)
        if choice then
            M.open(resolve(choice))
        end
    end)
end

--- Panel ---------------------------------------------------------------------
-- The clickable list itself lives in config/panel.lua; this only supplies the
-- project-specific data and actions.

local ADD_LABEL = "+ Add folder…"

---Ask the OS for a folder. Windows gets the real picker dialog; everywhere else
---falls back to a prompt.
---@param callback fun(path: string)
function M.choose_directory(callback)
    if vim.fn.has("win32") == 1 then
        local script = table.concat({
            "Add-Type -AssemblyName System.Windows.Forms;",
            "$d = New-Object System.Windows.Forms.FolderBrowserDialog;",
            "$d.Description = 'Choose a project folder';",
            "$d.ShowNewFolderButton = $true;",
            -- PowerShell single quotes are literal, so only ' needs doubling.
            ("$d.SelectedPath = '%s';"):format((M.current():gsub("/", "\\"):gsub("'", "''"))),
            "if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $d.SelectedPath };",
            "$d.Dispose()",
        }, " ")

        vim.system(
            { "powershell", "-NoProfile", "-STA", "-Command", script },
            { text = true },
            vim.schedule_wrap(function(result)
                local choice = vim.trim(result.stdout or "")
                if choice ~= "" then
                    callback(choice)
                end
            end)
        )

        return
    end

    vim.ui.input({ prompt = "Project directory: ", default = M.current(), completion = "dir" }, function(input)
        if input and input ~= "" then
            callback(input)
        end
    end)
end

---@return table[]
local function panel_entries()
    local entries = {}

    for _, root in ipairs(M.list()) do
        local name = vim.fs.basename(root)
        table.insert(entries, {
            id = root,
            name = name ~= "" and name or root,
            detail = vim.fs.normalize(vim.fn.fnamemodify(vim.fs.dirname(root), ":~")),
        })
    end

    return entries
end

---Open the mouse-driven project panel.
function M.panel()
    require("config.panel").open({
        kind = "projects",
        title = " Projects ",
        entries = panel_entries,
        empty = "No projects yet.",
        hint = "click open · ✕ forget · a add · d forget · q close",
        on_open = function(entry)
            M.open(entry.id)
        end,
        on_forget = function(entry)
            M.remove(entry.id)
            vim.notify("Forgot project: " .. vim.fn.fnamemodify(entry.id, ":~"))
        end,
        add = {
            label = ADD_LABEL,
            run = function(refresh)
                M.choose_directory(function(path)
                    local added = M.add(path)
                    if added then
                        vim.notify("Added project: " .. vim.fn.fnamemodify(added, ":~"))
                        refresh()
                    else
                        vim.notify("Not a usable project directory: " .. path, vim.log.levels.WARN)
                    end
                end)
            end,
        },
    })
end

---@param action "open"|"forget"|"add"
---@param lnum integer|nil
function M.panel_act(action, lnum)
    require("config.panel").act(action, lnum)
end

function M.close_panel()
    require("config.panel").close()
end

---Refresh the panel if it happens to be open (used after external changes).
function M.refresh_panel()
    require("config.panel").refresh()
end

---Run an fzf-lua picker scoped to the project root instead of the cwd.
---@param picker string
function M.in_root(picker)
    return function()
        local root = M.detect() or M.current()
        require("fzf-lua")[picker]({ cwd = root })
    end
end

local is_setup = false

function M.setup(opts)
    if is_setup then
        return
    end

    is_setup = true
    opts = opts or {}

    mkdirp(data_dir())

    -- mksession needs these to restore a usable layout.
    vim.opt.sessionoptions = {
        "buffers",
        "curdir",
        "folds",
        "help",
        "tabpages",
        "winsize",
        "winpos",
        "terminal",
    }

    local group = vim.api.nvim_create_augroup("ProjectManagement", { clear = true })

    if opts.open_directories ~= false then
        -- Opening a directory means "open this project". This covers
        -- `nvim D:\some\project`, `:edit <dir>`, and dragging a folder onto
        -- Neovide, which turns the drop into `:drop <path>`.
        -- BufNew and BufEnter can both fire for one directory, so latch.
        local pending = false

        vim.api.nvim_create_autocmd({ "BufNew", "BufEnter" }, {
            group = group,
            nested = true,
            desc = "Open a directory buffer as a project",
            callback = function(event)
                if pending then
                    return
                end

                local name = vim.api.nvim_buf_get_name(event.buf)

                if name == "" or vim.fn.isdirectory(name) ~= 1 then
                    return
                end

                -- neo-tree owns its own buffers; never hijack those.
                if vim.bo[event.buf].filetype == "neo-tree" then
                    return
                end

                pending = true
                local root = strip_trailing_slash(vim.fs.normalize(name))

                vim.schedule(function()
                    if vim.api.nvim_buf_is_valid(event.buf) and vim.bo[event.buf].filetype ~= "neo-tree" then
                        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
                    end

                    M.open(root)
                    pending = false
                end)
            end,
        })
    end

    -- Record any project a real file is opened from, so the list fills itself.
    vim.api.nvim_create_autocmd("BufReadPost", {
        group = group,
        callback = function(event)
            if vim.bo[event.buf].buftype ~= "" then
                return
            end

            local root = M.detect(vim.api.nvim_buf_get_name(event.buf))
            if root then
                M.add(root)
            end
        end,
    })

    if opts.auto_save_session ~= false then
        vim.api.nvim_create_autocmd("VimLeavePre", {
            group = group,
            callback = function()
                M.save_session()
            end,
        })
    end

    local command = vim.api.nvim_create_user_command

    command("ProjectOpen", function(args)
        if args.args ~= "" then
            M.open(args.args)
        else
            M.pick()
        end
    end, { nargs = "?", complete = "dir", desc = "Open a project" })

    command("ProjectAdd", function(args)
        local path = args.args ~= "" and args.args or M.detect() or M.current()
        local added = M.add(path)

        if added then
            vim.notify("Added project: " .. added, vim.log.levels.INFO)
        else
            vim.notify("Not a usable project directory: " .. path, vim.log.levels.WARN)
        end
    end, { nargs = "?", complete = "dir", desc = "Add a project to the list" })

    command("ProjectRemove", function(args)
        local path = args.args ~= "" and args.args or M.current()
        M.remove(path)
        vim.notify("Removed project: " .. path, vim.log.levels.INFO)
    end, { nargs = "?", complete = "dir", desc = "Remove a project from the list" })

    command("ProjectRoot", function()
        M.cd_to_root()
    end, { desc = "cd to the project root of the current buffer" })

    command("ProjectPanel", function()
        M.panel()
    end, { desc = "Toggle the mouse-driven project panel" })

    command("ProjectSessionSave", function()
        if M.save_session() then
            vim.notify("Session saved for " .. M.current(), vim.log.levels.INFO)
        end
    end, { desc = "Save the session for the current project" })

    command("ProjectSessionLoad", function()
        if not M.load_session() then
            vim.notify("No session for " .. M.current(), vim.log.levels.WARN)
        end
    end, { desc = "Load the session for the current project" })

    command("ProjectSessionDelete", function()
        M.delete_session()
        vim.notify("Session deleted for " .. M.current(), vim.log.levels.INFO)
    end, { desc = "Delete the session for the current project" })
end

return M
