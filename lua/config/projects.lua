local M = {}

function M.set_root(path)
    local normalized = vim.fs.normalize(path)
    vim.cmd("cd " .. vim.fn.fnameescape(normalized))
    return normalized
end

return M
