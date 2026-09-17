-- Recent files, with a mouse-driven list.
--
-- Neovim already tracks recency in `v:oldfiles` (rebuilt from shada on every
-- start), so this does not keep its own history. "Forget" is a persisted
-- exclusion set instead: the entry is hidden until the file is opened again,
-- at which point it earns its place back.
local M = {}

local uv = vim.uv or vim.loop

-- `vim.g.recent_data_dir` lets tests point the store somewhere disposable.
local function data_dir()
    return vim.g.recent_data_dir or vim.fs.joinpath(vim.fn.stdpath("data"), "projects")
end

local function ignore_file()
    return vim.fs.joinpath(data_dir(), "recent-ignored.json")
end

M.limit = 30

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
    vim.fn.mkdir(vim.fs.dirname(path), "p")

    local fd = uv.fs_open(path, "w", 420)
    if not fd then
        return false
    end

    uv.fs_write(fd, data, 0)
    uv.fs_close(fd)

    return true
end

---@param path string
---@return string
local function normalize(path)
    return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

---@return table<string, boolean>
local function ignored()
    local data = read_file(ignore_file())
    if not data or data == "" then
        return {}
    end

    local ok, decoded = pcall(vim.json.decode, data)
    if not ok or type(decoded) ~= "table" then
        return {}
    end

    local set = {}
    for _, entry in ipairs(decoded) do
        if type(entry) == "string" then
            set[entry] = true
        end
    end

    return set
end

---@param set table<string, boolean>
local function persist(set)
    local list = vim.tbl_keys(set)
    table.sort(list)
    write_file(ignore_file(), vim.json.encode(list))
end

-- `v:oldfiles` is built from shada at startup and never grows during the
-- session, so files opened right now would not show up at all. Track them here
-- and merge them in front.
local session_files = {}

---@param path string
local function touch(path)
    local target = normalize(path)
    local merged = { target }

    for _, entry in ipairs(session_files) do
        if entry ~= target then
            table.insert(merged, entry)
        end
    end

    session_files = merged
end

---@param path string
local function drop_from_session(path)
    local target = normalize(path)
    local remaining = {}

    for _, entry in ipairs(session_files) do
        if entry ~= target then
            table.insert(remaining, entry)
        end
    end

    session_files = remaining
end

---Recent files, newest first: readable, not ignored, de-duplicated.
---@return string[]
function M.list()
    local skip = ignored()
    local files, seen = {}, {}

    local function consider(entry)
        local path = normalize(entry)

        if seen[path] or skip[path] or vim.fn.filereadable(path) ~= 1 then
            return
        end

        seen[path] = true
        table.insert(files, path)
    end

    for _, entry in ipairs(session_files) do
        consider(entry)
        if #files >= M.limit then
            return files
        end
    end

    for _, entry in ipairs(vim.v.oldfiles or {}) do
        consider(entry)
        if #files >= M.limit then
            break
        end
    end

    return files
end

---Hide a file from the recent list until it is opened again. `v:oldfiles` is
---left alone: it is the shada-backed history, and rewriting it would mean a
---re-opened file could not come back until the next restart.
---@param path string
function M.forget(path)
    local target = normalize(path)

    local skip = ignored()
    skip[target] = true
    persist(skip)

    drop_from_session(target)
end

---Stop hiding a file.
---@param path string
function M.remember(path)
    local target = normalize(path)
    local skip = ignored()

    if skip[target] then
        skip[target] = nil
        persist(skip)
    end
end

---Hide everything currently listed.
function M.clear()
    local skip = ignored()

    for _, path in ipairs(M.list()) do
        skip[path] = true
    end

    persist(skip)
    session_files = {}
end

---Forget every exclusion, bringing the full history back.
function M.reset()
    persist({})
end

---@param path string
function M.open(path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
end

---Ask the OS for a file. Windows gets the real dialog; elsewhere, a prompt.
---@param callback fun(path: string)
function M.choose_file(callback)
    if vim.fn.has("win32") == 1 then
        local script = table.concat({
            "Add-Type -AssemblyName System.Windows.Forms;",
            "$d = New-Object System.Windows.Forms.OpenFileDialog;",
            "$d.Title = 'Open file';",
            "$d.Filter = 'All files (*.*)|*.*';",
            -- PowerShell single quotes are literal, so only ' needs doubling.
            ("$d.InitialDirectory = '%s';"):format((vim.fs.normalize(vim.fn.getcwd()):gsub("/", "\\"):gsub("'", "''"))),
            "if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $d.FileName };",
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

    vim.ui.input({ prompt = "File: ", default = vim.fn.getcwd() .. "/", completion = "file" }, function(input)
        if input and input ~= "" then
            callback(input)
        end
    end)
end

---@return table[]
local function panel_entries()
    local entries = {}

    for _, path in ipairs(M.list()) do
        table.insert(entries, {
            id = path,
            name = vim.fs.basename(path),
            detail = vim.fs.normalize(vim.fn.fnamemodify(vim.fs.dirname(path), ":~")),
        })
    end

    return entries
end

---Open the mouse-driven recent-files panel.
function M.panel()
    require("config.panel").open({
        kind = "recent",
        title = " Recent Files ",
        entries = panel_entries,
        empty = "No recent files.",
        hint = "click open · ✕ forget · a open file · d forget · q close",
        on_open = function(entry)
            M.open(entry.id)
        end,
        on_forget = function(entry)
            M.forget(entry.id)
            vim.notify("Forgot recent file: " .. vim.fn.fnamemodify(entry.id, ":~"))
        end,
        add = {
            label = "+ Open file…",
            run = function()
                M.choose_file(function(path)
                    require("config.panel").close()
                    M.open(path)
                end)
            end,
        },
    })
end

local is_setup = false

function M.setup()
    if is_setup then
        return
    end

    is_setup = true

    -- Opening a file records it for this session and cancels a previous "forget".
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        group = vim.api.nvim_create_augroup("RecentFiles", { clear = true }),
        callback = function(event)
            if vim.bo[event.buf].buftype ~= "" then
                return
            end

            local name = vim.api.nvim_buf_get_name(event.buf)
            if name ~= "" and vim.fn.filereadable(name) == 1 then
                M.remember(name)
                touch(name)
            end
        end,
    })

    local command = vim.api.nvim_create_user_command

    command("RecentFiles", function()
        M.panel()
    end, { desc = "Toggle the mouse-driven recent files panel" })

    command("RecentForget", function(args)
        local path = args.args ~= "" and args.args or vim.api.nvim_buf_get_name(0)
        if path == "" then
            vim.notify("This buffer has no file path", vim.log.levels.WARN)
            return
        end

        M.forget(path)
        vim.notify("Forgot recent file: " .. vim.fn.fnamemodify(path, ":~"))
        require("config.panel").refresh()
    end, { nargs = "?", complete = "file", desc = "Hide a file from the recent list" })

    command("RecentClear", function()
        M.clear()
        vim.notify("Recent files cleared")
        require("config.panel").refresh()
    end, { desc = "Hide every current recent file" })

    command("RecentReset", function()
        M.reset()
        vim.notify("Recent file history restored")
        require("config.panel").refresh()
    end, { desc = "Undo every recent-file exclusion" })
end

return M
