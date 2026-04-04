local buffers = require("config.buffers")
buffers.setup()

local function fzf(picker, opts)
    return function()
        require("fzf-lua")[picker](opts or {})
    end
end

local function cmake(command, fallback)
    return function()
        if vim.fn.exists(":" .. command) > 0 then
            local ok, err = pcall(vim.cmd, command)
            if ok then
                return
            end

            if not fallback then
                vim.notify(err, vim.log.levels.ERROR)
                return
            end
        end

        if fallback and vim.fn.exists(":" .. fallback) > 0 then
            local ok, err = pcall(vim.cmd, fallback)
            if ok then
                return
            end

            vim.notify(err, vim.log.levels.ERROR)
            return
        end

        vim.notify("CMake command is not available: " .. command, vim.log.levels.WARN)
    end
end

local function open_config_file(path)
    return function()
        local full_path = vim.fs.joinpath(vim.fn.stdpath("config"), path)
        vim.cmd.edit(vim.fn.fnameescape(full_path))
    end
end

local function close_current_buffer()
    buffers.close()
end

local function smart_quit(force)
    return function()
        buffers.quit({ force = force })
    end
end

local function smart_write_quit(force)
    return function()
        buffers.write_quit({ force = force })
    end
end

local function smart_buffer_close()
    return function()
        buffers.close()
    end
end

local function smart_buffer_wipe()
    return function()
        buffers.wipe()
    end
end

local map = vim.keymap.set
-- Move by screenlines instead of actual lines when using up/down keys in normal and visual mode, and when using up/down keys in insert mode
map({ "n", "v" }, "<Up>", "gk", { desc = "Move up a screenline" })
map({ "n", "v" }, "<Down>", "gj", { desc = "Move down a screenline" })
map("i", "<Up>", "<C-o>gk", { desc = "Move up a screenline" })
map("i", "<Down>", "<C-o>gj", { desc = "Move down a screenline" })
-- Append/prepend empty line without leaving normal mode
map('n', 'O', "O<Esc>", { desc = "Append empty line" })
map('n', 'o', "o<Esc>", { desc = "Prepend empty line" })
-- Don't copy deleted text into the default register when using x/X in normal and visual mode
map({ "n", "v" }, "x", '"_x')
map({ "n", "v" }, "X", '"_X')
-- Avoid accidentally showing the built-in cursor info panel under the statusline
map({ "n", "x" }, "g<C-g>", "<Nop>", { desc = "Disable built-in cursor info" })
map("n", "<leader>ui", vim.show_pos, { desc = "Show cursor info" })
-- LSP keymaps (only work when an LSP server is attached to the buffer)
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename" })
map("n", "K", vim.lsp.buf.hover, { desc = "Hover" })
-- FZF keymaps
map("n", "<leader>ff", fzf("files"), { desc = "Find files" })
map("n", "<leader>fg", fzf("live_grep"), { desc = "Live grep" })
map("n", "<leader>fw", fzf("grep_cword"), { desc = "Grep current word" })
map("n", "<leader>fb", fzf("buffers"), { desc = "Find buffers" })
map("n", "<leader>fo", fzf("oldfiles"), { desc = "Find old files" })
map("n", "<leader>fh", fzf("help_tags"), { desc = "Help tags" })
map("n", "<leader>fk", fzf("keymaps"), { desc = "Find keymaps" })
map("n", "<leader>fc", open_config_file("docs/cheatsheet.md"), { desc = "Open cheatsheet" })
map({ "n", "i" }, "<C-Tab>", "<Cmd>BufferLineCycleNext<CR>", { desc = "Next buffer tab" })
map({ "n", "i" }, "<C-S-Tab>", "<Cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer tab" })
map("n", "<leader>w", "<Cmd>write<CR>", { desc = "Write current buffer" })
map("n", "<leader>q", smart_quit(false), { desc = "Smart quit current buffer" })
map("n", "<leader>x", smart_write_quit(false), { desc = "Smart write and quit current buffer" })
map("n", "<leader>bd", close_current_buffer, { desc = "Delete current buffer" })

vim.api.nvim_create_user_command("SmartQuit", smart_quit(false), {})
vim.api.nvim_create_user_command("SmartQuitForce", smart_quit(true), {})
vim.api.nvim_create_user_command("SmartWriteQuit", smart_write_quit(false), {})
vim.api.nvim_create_user_command("SmartWriteQuitForce", smart_write_quit(true), {})
vim.api.nvim_create_user_command("SmartBdelete", smart_buffer_close(), {})
vim.api.nvim_create_user_command("SmartBwipeout", smart_buffer_wipe(), {})

vim.cmd([[
  cnoreabbrev <expr> q ((getcmdtype() ==# ':' && getcmdline() ==# 'q') ? 'SmartQuit' : 'q')
  cnoreabbrev <expr> quit ((getcmdtype() ==# ':' && getcmdline() ==# 'quit') ? 'SmartQuit' : 'quit')
  cnoreabbrev <expr> q! ((getcmdtype() ==# ':' && getcmdline() ==# 'q!') ? 'SmartQuitForce' : 'q!')
  cnoreabbrev <expr> quit! ((getcmdtype() ==# ':' && getcmdline() ==# 'quit!') ? 'SmartQuitForce' : 'quit!')
  cnoreabbrev <expr> bd ((getcmdtype() ==# ':' && getcmdline() ==# 'bd') ? 'SmartBdelete' : 'bd')
  cnoreabbrev <expr> bdelete ((getcmdtype() ==# ':' && getcmdline() ==# 'bdelete') ? 'SmartBdelete' : 'bdelete')
  cnoreabbrev <expr> bw ((getcmdtype() ==# ':' && getcmdline() ==# 'bw') ? 'SmartBwipeout' : 'bw')
  cnoreabbrev <expr> bwipeout ((getcmdtype() ==# ':' && getcmdline() ==# 'bwipeout') ? 'SmartBwipeout' : 'bwipeout')
  cnoreabbrev <expr> wq ((getcmdtype() ==# ':' && getcmdline() ==# 'wq') ? 'SmartWriteQuit' : 'wq')
  cnoreabbrev <expr> waq ((getcmdtype() ==# ':' && getcmdline() ==# 'waq') ? 'SmartWriteQuit' : 'waq')
  cnoreabbrev <expr> x ((getcmdtype() ==# ':' && getcmdline() ==# 'x') ? 'SmartWriteQuit' : 'x')
  cnoreabbrev <expr> exit ((getcmdtype() ==# ':' && getcmdline() ==# 'exit') ? 'SmartWriteQuit' : 'exit')
  cnoreabbrev <expr> xit ((getcmdtype() ==# ':' && getcmdline() ==# 'xit') ? 'SmartWriteQuit' : 'xit')
  cnoreabbrev <expr> wq! ((getcmdtype() ==# ':' && getcmdline() ==# 'wq!') ? 'SmartWriteQuitForce' : 'wq!')
  cnoreabbrev <expr> waq! ((getcmdtype() ==# ':' && getcmdline() ==# 'waq!') ? 'SmartWriteQuitForce' : 'waq!')
]])

map("n", "<leader>ld", fzf("lsp_definitions"), { desc = "LSP definitions" })
map("n", "<leader>lr", fzf("lsp_references"), { desc = "LSP references" })
map("n", "<leader>li", fzf("lsp_implementations"), { desc = "LSP implementations" })
map("n", "<leader>lt", fzf("lsp_typedefs"), { desc = "LSP typedefs" })
map("n", "<leader>ls", fzf("lsp_document_symbols"), { desc = "Document symbols" })
map("n", "<leader>lS", fzf("lsp_live_workspace_symbols"), { desc = "Workspace symbols" })
map("n", "<leader>lx", fzf("diagnostics_document"), { desc = "Document diagnostics" })
map("n", "<leader>lq", fzf("quickfix"), { desc = "Quickfix list" })

map("n", "<leader>gf", fzf("git_files"), { desc = "Git files" })
map("n", "<leader>gs", fzf("git_status"), { desc = "Git status" })
map("n", "<leader>gc", fzf("git_commits"), { desc = "Git commits" })
map("n", "<leader>gb", fzf("git_branches"), { desc = "Git branches" })
map("n", "<leader>gh", fzf("git_bcommits"), { desc = "Git file history" })

map("n", "<leader>cc", cmake("CMakeGenerate"), { desc = "CMake configure" })
map("n", "<leader>cb", cmake("CMakeBuild"), { desc = "CMake build" })
map("n", "<leader>cr", cmake("CMakeRun"), { desc = "CMake run" })
map("n", "<leader>ct", cmake("CMakeSelectBuildTarget"), { desc = "CMake build target" })
map("n", "<leader>cs", cmake("CMakeSelectLaunchTarget"), { desc = "CMake launch target" })
map("n", "<leader>cp", cmake("CMakeSelectConfigurePreset", "CMakeSelectKit"), { desc = "CMake preset or kit" })

map("n", "<Leader>;", function()
    require("dropbar.api").pick()
end, { desc = "Pick symbols in winbar" })

map("n", "[;", function()
    require("dropbar.api").goto_context_start()
end, { desc = "Go to start of current context" })

map("n", "];", function()
    require("dropbar.api").select_next_context()
end, { desc = "Select next context" })

map("n", "sn", function()
    MiniSurround.update_n_lines()
end, { desc = "Update surround search lines" })
