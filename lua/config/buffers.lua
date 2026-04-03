local M = {}
local augroup = vim.api.nvim_create_augroup("SafeBufferClose", { clear = true })
local is_setup = false

local ignored_filetypes = {
    ["dashboard"] = true,
    ["neo-tree"] = true,
}

local function is_editor_buffer(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return false
    end

    if vim.api.nvim_buf_get_name(bufnr) == "" and not vim.api.nvim_buf_is_loaded(bufnr) then
        return false
    end

    if vim.fn.buflisted(bufnr) ~= 1 then
        return false
    end

    if vim.bo[bufnr].buftype ~= "" then
        return false
    end

    return not ignored_filetypes[vim.bo[bufnr].filetype]
end

local function editor_buffers()
    local buffers = {}

    for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        if is_editor_buffer(info.bufnr) then
            table.insert(buffers, info.bufnr)
        end
    end

    table.sort(buffers)

    return buffers
end

local function editor_buffer_count()
    return #editor_buffers()
end

local function next_buffer(bufnr)
    local buffers = editor_buffers()

    for index, candidate in ipairs(buffers) do
        if candidate == bufnr then
            return buffers[index + 1] or buffers[index - 1]
        end
    end
end

local function create_placeholder_buffer()
    local bufnr = vim.api.nvim_create_buf(false, true)

    vim.bo[bufnr].bufhidden = "hide"
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].swapfile = false

    return bufnr
end

local function replace_windows_with_placeholder(bufnr)
    local windows = vim.fn.win_findbuf(bufnr)
    if vim.tbl_isempty(windows) then
        return
    end

    local placeholder = create_placeholder_buffer()

    for _, winid in ipairs(windows) do
        if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
            vim.api.nvim_win_set_buf(winid, placeholder)
        end
    end
end

local function confirm_close(bufnr)
    if not vim.bo[bufnr].modified then
        return true, false
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
        name = "[No Name]"
    else
        name = vim.fn.fnamemodify(name, ":.")
    end

    local choice = vim.fn.confirm(("Save changes to %s?"):format(name), "&Yes\n&No\n&Cancel", 1)

    if choice == 1 then
        local ok, err = pcall(vim.api.nvim_buf_call, bufnr, function()
            vim.cmd("write")
        end)

        if not ok then
            vim.notify(err, vim.log.levels.ERROR)
            return false, false
        end

        return true, false
    end

    if choice == 2 then
        return true, true
    end

    return false, false
end

function M.close(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
        return
    end

    local proceed, force = confirm_close(bufnr)
    if not proceed then
        return
    end

    local replacement = next_buffer(bufnr)
    if replacement == bufnr then
        replacement = nil
    end

    if replacement then
        local windows = vim.fn.win_findbuf(bufnr)

        for _, winid in ipairs(windows) do
            if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
                vim.api.nvim_win_set_buf(winid, replacement)
            end
        end
    else
        replace_windows_with_placeholder(bufnr)
    end

    local ok, err = pcall(vim.api.nvim_buf_delete, bufnr, { force = force })
    if not ok then
        vim.notify(err, vim.log.levels.ERROR)
    end
end

function M.quit(opts)
    opts = opts or {}

    local bufnr = vim.api.nvim_get_current_buf()
    local is_editor = is_editor_buffer(bufnr)

    if is_editor then
        M.close(bufnr)
        return
    end

    vim.cmd(opts.force and "quit!" or "quit")
end

function M.write_quit(opts)
    opts = opts or {}

    if is_editor_buffer(vim.api.nvim_get_current_buf()) then
        vim.cmd(opts.force and "write!" or "write")
    end

    M.quit(opts)
end

function M.wipe(bufnr)
    M.close(bufnr)
end

function M.setup()
    if is_setup then
        return
    end

    is_setup = true

    vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
        group = augroup,
        callback = function(event)
            if is_editor_buffer(event.buf) and editor_buffer_count() == 1 then
                replace_windows_with_placeholder(event.buf)
            end
        end,
    })
end

return M
