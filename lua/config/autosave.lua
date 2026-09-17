-- Write a file back as soon as you stop editing it: on leaving insert mode, on
-- moving to another buffer or window, and when Neovim loses focus.
--
-- Autosaving deliberately does not run the formatter. conform.nvim formats on
-- BufWritePre, and having clang-format reflow half-written code every time you
-- press <Esc> moves the cursor out from under you. `<leader>w` still formats.
local M = {}

---Buffers that are edited to be written once, by hand.
local ignored_filetypes = {
    ["gitcommit"] = true,
    ["gitrebase"] = true,
}

---@param buf integer
---@return boolean
function M.should_save(buf)
    if vim.g.autosave_disable or vim.b[buf].autosave_disable then
        return false
    end

    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
        return false
    end

    -- Only real files: no terminals, no help, no scratch, no `acwrite` buffers
    -- owned by a plugin.
    if vim.bo[buf].buftype ~= "" then
        return false
    end

    if not vim.bo[buf].modified or not vim.bo[buf].modifiable or vim.bo[buf].readonly then
        return false
    end

    if ignored_filetypes[vim.bo[buf].filetype] then
        return false
    end

    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then
        return false
    end

    -- A file under a directory that does not exist yet cannot be written, and
    -- the failure would repeat on every keystroke.
    return vim.fn.isdirectory(vim.fn.fnamemodify(name, ":h")) == 1
end

---Write `buf` without formatting it.
---@param buf integer|nil
---@return boolean written
function M.save(buf)
    buf = buf or vim.api.nvim_get_current_buf()

    if not M.should_save(buf) then
        return false
    end

    -- conform.nvim's own opt-out, so a manual `:FormatToggle!` is preserved
    -- rather than overwritten.
    local formatting_was_disabled = vim.b[buf].disable_autoformat
    vim.b[buf].disable_autoformat = true

    local ok, err = pcall(function()
        vim.api.nvim_buf_call(buf, function()
            vim.cmd("silent write")
        end)
    end)

    vim.b[buf].disable_autoformat = formatting_was_disabled

    if not ok then
        vim.notify("Autosave failed: " .. tostring(err), vim.log.levels.WARN)
        return false
    end

    return true
end

local is_setup = false

function M.setup()
    if is_setup then
        return
    end

    is_setup = true

    vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave", "WinLeave", "FocusLost" }, {
        group = vim.api.nvim_create_augroup("AutoSave", { clear = true }),
        callback = function(event)
            M.save(event.buf)
        end,
    })

    vim.api.nvim_create_user_command("AutoSaveToggle", function(args)
        if args.bang then
            vim.b.autosave_disable = not vim.b.autosave_disable
            vim.notify("Autosave (buffer): " .. (vim.b.autosave_disable and "off" or "on"))
            return
        end

        vim.g.autosave_disable = not vim.g.autosave_disable
        vim.notify("Autosave: " .. (vim.g.autosave_disable and "off" or "on"))
    end, { bang = true, desc = "Toggle autosave (! for this buffer only)" })

    vim.api.nvim_create_user_command("AutoSaveNow", function()
        if not M.save() then
            vim.notify("Nothing to autosave in this buffer", vim.log.levels.INFO)
        end
    end, { desc = "Write the current buffer the way autosave does, without formatting" })
end

return M
