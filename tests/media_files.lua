-- Opening an image, a sound or a video must hand the file to the system player
-- and leave no buffer behind, rather than reading binary noise into a window.
local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(("%s\nexpected: %s\nactual: %s"):format(message, vim.inspect(expected), vim.inspect(actual)))
    end
end

local function assert_truthy(value, message)
    if not value then
        error(message)
    end
end

local script_path = vim.fs.normalize(debug.getinfo(1, "S").source:sub(2))
local config_root = vim.fs.dirname(vim.fs.dirname(script_path))

package.path = table.concat({
    vim.fs.joinpath(config_root, "lua", "?.lua"),
    vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
    package.path,
}, ";")

local media = require("config.media")

assert_equal(media.kind("C:/pictures/cat.PNG"), "image", "expected .PNG to be an image, case and all")
assert_equal(media.kind("song.mp3"), "audio", "expected .mp3 to be audio")
assert_equal(media.kind("clip.mkv"), "video", "expected .mkv to be video")
assert_equal(media.kind("notes.md"), nil, "expected a text file not to be media")
assert_equal(media.kind("logo.svg"), nil, "expected SVG to stay editable text")

-- Record what would have been handed to the OS.
local opened = {}
vim.ui.open = function(path)
    table.insert(opened, path)
    return { wait = function() end }, nil
end

media.setup()
media.setup() -- idempotent

local sandbox = vim.fn.tempname()
vim.fn.mkdir(sandbox, "p")

local text = vim.fs.joinpath(sandbox, "notes.md")
vim.fn.writefile({ "# hello" }, text)

local image = vim.fs.joinpath(sandbox, "cat.png")
vim.fn.writefile({ "\137PNG\r\n\26\n" }, image, "b")

vim.cmd("edit " .. vim.fn.fnameescape(text))
local text_buf = vim.api.nvim_get_current_buf()

vim.cmd("edit " .. vim.fn.fnameescape(image))
local image_buf = vim.api.nvim_get_current_buf()

assert_equal(#opened, 1, "expected opening an image to reach the system player")
assert_equal(vim.fs.normalize(opened[1]), vim.fs.normalize(image), "expected the image path to be the one opened")
assert_equal(
    vim.api.nvim_buf_line_count(image_buf) == 1 and vim.api.nvim_buf_get_lines(image_buf, 0, -1, false)[1],
    "",
    "expected nothing to be read into the buffer"
)

-- The buffer is taken apart on the next tick.
vim.wait(1000, function()
    return not vim.api.nvim_buf_is_valid(image_buf)
end)

assert_truthy(not vim.api.nvim_buf_is_valid(image_buf), "expected the media buffer to be gone")
assert_equal(vim.api.nvim_get_current_buf(), text_buf, "expected the window to fall back to the previous file")

-- A text file is untouched.
vim.cmd("edit " .. vim.fn.fnameescape(text))
assert_equal(#opened, 1, "expected a text file not to reach the player")
assert_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1], "# hello", "expected the text file to be read normally")

-- The escape hatch gets the raw bytes back.
vim.g.media_autoopen = false
vim.cmd("edit " .. vim.fn.fnameescape(image))

assert_equal(#opened, 1, "expected media_autoopen = false to skip the player")
assert_equal(
    vim.fs.normalize(vim.api.nvim_buf_get_name(0)),
    vim.fs.normalize(image),
    "expected media_autoopen = false to load the file itself"
)
vim.g.media_autoopen = nil

-- :MediaOpen works on a path and on the current buffer.
vim.cmd("MediaOpen " .. vim.fn.fnameescape(image))
assert_equal(#opened, 2, "expected :MediaOpen to reach the player")

vim.cmd("qa!")
