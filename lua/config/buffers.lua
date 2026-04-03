local M = {}

local ignored_filetypes = {
    ["dashboard"] = true,
    ["neo-tree"] = true,
}

local function is_editor_buffer(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
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

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].swapfile = false

    return bufnr
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

    local windows = vim.fn.win_findbuf(bufnr)
    local placeholder = replacement and nil or create_placeholder_buffer()

    for _, winid in ipairs(windows) do
        if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
            vim.api.nvim_win_set_buf(winid, replacement or placeholder)
        end
    end

    local ok, err = pcall(vim.api.nvim_buf_delete, bufnr, { force = force })
    if not ok then
        vim.notify(err, vim.log.levels.ERROR)
    end
end

return M
