-- Media files are handed to the system player instead of being read into a
-- buffer. Neovim has no way to render an image, let alone play audio or video,
-- so loading one only fills the window with binary noise and leaves a buffer
-- that has to be closed again. `BufReadCmd` replaces the read itself, which is
-- why this catches every route into a file: `:edit`, neo-tree, fzf-lua, a
-- command-line argument, or a drop onto Neovide.
local M = {}

---@type table<string, "image"|"audio"|"video">
local kinds = {}

local function register(kind, extensions)
    for _, extension in ipairs(extensions) do
        kinds[extension] = kind
    end
end

-- SVG is deliberately absent: it is text, and editing one is a normal thing to
-- want to do.
register("image", { "png", "jpg", "jpeg", "gif", "bmp", "webp", "ico", "tif", "tiff", "avif", "heic" })
register("audio", { "mp3", "wav", "flac", "ogg", "oga", "m4a", "aac", "wma", "opus" })
register("video", { "mp4", "mkv", "avi", "mov", "wmv", "webm", "flv", "m4v", "mpg", "mpeg" })

---@param path string
---@return "image"|"audio"|"video"|nil
function M.kind(path)
    return kinds[vim.fn.fnamemodify(path, ":e"):lower()]
end

---@return string[]
function M.extensions()
    return vim.tbl_keys(kinds)
end

---Hand `path` to whatever the OS opens it with.
---@param path string
---@return boolean
function M.open(path)
    local ok, err = pcall(vim.ui.open, path)

    if not ok then
        vim.notify("Could not open " .. path .. ": " .. tostring(err), vim.log.levels.ERROR)
        return false
    end

    vim.notify(("Opened %s in the system player"):format(vim.fn.fnamemodify(path, ":t")))

    return true
end

---A buffer to leave the window on once the media buffer goes away: the file
---that was being edited before, or an empty scratch when there is none.
---@param buf integer
---@return integer
local function replacement_for(buf)
    local alternate = vim.fn.bufnr("#")

    if alternate ~= -1 and alternate ~= buf and vim.api.nvim_buf_is_valid(alternate) then
        return alternate
    end

    local scratch = vim.api.nvim_create_buf(false, true)

    vim.bo[scratch].bufhidden = "hide"
    vim.bo[scratch].buftype = "nofile"
    vim.bo[scratch].swapfile = false

    return scratch
end

---Drop the buffer Neovim created for the media file. Nothing was read into it,
---so leaving it around would only be a buffer the user has to close by hand.
---@param buf integer
local function dismiss(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end

    local replacement = replacement_for(buf)

    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
            vim.api.nvim_win_set_buf(win, replacement)
        end
    end

    pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

local is_setup = false

function M.setup()
    if is_setup then
        return
    end

    is_setup = true

    -- "*.png" and "*.PNG" both match on Windows, where autocommand patterns are
    -- case-insensitive, and the callback would run twice. One "*.[pP][nN][gG]"
    -- per extension matches any spelling exactly once, on every platform.
    local patterns = {}
    for extension in pairs(kinds) do
        local glob = "*."
        for character in extension:gmatch(".") do
            glob = glob .. "[" .. character .. character:upper() .. "]"
        end
        table.insert(patterns, glob)
    end

    vim.api.nvim_create_autocmd("BufReadCmd", {
        group = vim.api.nvim_create_augroup("MediaFiles", { clear = true }),
        pattern = patterns,
        callback = function(event)
            local path = event.match ~= "" and event.match or event.file

            -- `vim.g.media_autoopen = false` gets the raw bytes back. The read
            -- has to be done here: a BufReadCmd replaces it, so returning early
            -- would only leave an empty buffer.
            if vim.g.media_autoopen == false then
                vim.api.nvim_buf_call(event.buf, function()
                    vim.cmd("keepalt silent read ++edit " .. vim.fn.fnameescape(path))
                    vim.cmd("silent 1delete _")
                end)
                vim.bo[event.buf].modified = false
                return
            end

            M.open(path)

            -- The read is being replaced, so the buffer can only be taken apart
            -- once Neovim is done with it.
            vim.schedule(function()
                dismiss(event.buf)
            end)
        end,
    })

    vim.api.nvim_create_user_command("MediaOpen", function(args)
        local path = args.args ~= "" and args.args or vim.api.nvim_buf_get_name(0)

        if path == "" then
            vim.notify("This buffer has no file path", vim.log.levels.WARN)
            return
        end

        M.open(vim.fn.fnamemodify(path, ":p"))
    end, { nargs = "?", complete = "file", desc = "Open a file in the system player" })
end

return M
