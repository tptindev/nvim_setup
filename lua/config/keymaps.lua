local buffers = require("config.buffers")
buffers.setup()

local projects = require("config.projects")
projects.setup()

local recent = require("config.recent")
recent.setup()

require("config.media").setup()
require("config.autosave").setup()
require("config.mouse").setup()

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

local function smart_write(force)
    return function()
        if vim.bo.buftype ~= "" then
            vim.notify("Current buffer cannot be written", vim.log.levels.WARN)
            return
        end

        vim.cmd(force and "write!" or "write")
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

local function notify_use_fine_cmdline()
    vim.notify("Use <leader>: for fine command line", vim.log.levels.INFO)
end

local function set_lsp_keymaps(event)
    local opts = { buffer = event.buf }
    local map = vim.keymap.set
    local client = vim.lsp.get_client_by_id(event.data and event.data.client_id)

    map("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Goto definition" }))
    map("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "Goto declaration" }))
    map("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover" }))
    map("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename" }))
    map("n", "<leader>la", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
    map("n", "<leader>lf", function()
        require("conform").format({ async = true, lsp_format = "fallback" })
    end, vim.tbl_extend("force", opts, { desc = "Format buffer" }))
    map("n", "[d", function()
        vim.diagnostic.jump({ count = -1, float = true })
    end, vim.tbl_extend("force", opts, { desc = "Previous diagnostic" }))
    map("n", "]d", function()
        vim.diagnostic.jump({ count = 1, float = true })
    end, vim.tbl_extend("force", opts, { desc = "Next diagnostic" }))
    map("n", "<leader>ln", function()
        local bufnr = event.buf
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
    end, vim.tbl_extend("force", opts, { desc = "Toggle inlay hints" }))

    if client and client.name == "clangd" then
        map("n", "<leader>lh", "<cmd>LspClangdSwitchSourceHeader<CR>", vim.tbl_extend("force", opts, { desc = "Switch source/header" }))
    end

    if client and client.name == "clangd" and client.server_capabilities.inlayHintProvider then
        vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
    end
end

local map = vim.keymap.set
-- Move by screenlines instead of actual lines when using up/down keys in normal and visual mode, and when using up/down keys in insert mode
map({ "n", "v" }, "<Up>", "gk", { desc = "Move up a screenline" })
map({ "n", "v" }, "<Down>", "gj", { desc = "Move down a screenline" })
map("i", "<Up>", "<C-o>gk", { desc = "Move up a screenline" })
map("i", "<Down>", "<C-o>gj", { desc = "Move down a screenline" })
-- Move line(s) up/down with Alt+j / Alt+k
map("n", "<A-j>", "<cmd>m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<CR>==", { desc = "Move line up" })
map("i", "<A-j>", "<Esc><cmd>m .+1<CR>==gi", { desc = "Move line down" })
map("i", "<A-k>", "<Esc><cmd>m .-2<CR>==gi", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
-- Append/prepend empty line without leaving normal mode
map('n', 'O', "O<Esc>", { desc = "Append empty line" })
map('n', 'o', "o<Esc>", { desc = "Prepend empty line" })
-- Don't copy deleted text into the default register when using x/X in normal and visual mode
map({ "n", "v" }, "x", '"_x')
map({ "n", "v" }, "X", '"_X')
-- Avoid accidentally showing the built-in cursor info panel under the statusline
map({ "n", "x" }, "g<C-g>", "<Nop>", { desc = "Disable built-in cursor info" })
map("n", ":", notify_use_fine_cmdline, { desc = "Use fine command line" })
map("n", "<leader>ui", vim.show_pos, { desc = "Show cursor info" })
map("n", "<leader>sk", function()
    require("screenkey").toggle()
end, { desc = "Toggle screenkey" })
-- FZF keymaps
map("n", "<leader>ff", fzf("files"), { desc = "Find files" })
map("n", "<leader>fg", fzf("live_grep"), { desc = "Live grep" })
map("n", "<leader>fw", fzf("grep_cword"), { desc = "Grep current word" })
map("n", "<leader>fb", fzf("buffers"), { desc = "Find buffers" })
map("n", "<leader>fo", fzf("oldfiles"), { desc = "Find old files" })
map("n", "<leader>fr", recent.panel, { desc = "Recent files panel (mouse)" })
map("n", "<leader>fh", fzf("help_tags"), { desc = "Help tags" })
map("n", "<leader>fk", fzf("keymaps"), { desc = "Find keymaps" })
map("n", "<leader>fc", open_config_file("docs/cheatsheet.md"), { desc = "Open cheatsheet" })
map({ "n", "i" }, "<C-Tab>", "<Cmd>BufferLineCycleNext<CR>", { desc = "Next buffer tab" })
map({ "n", "i" }, "<C-S-Tab>", "<Cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer tab" })
map("n", "<leader>w", smart_write(false), { desc = "Write current buffer" })
map("n", "<leader>q", smart_quit(false), { desc = "Smart quit current buffer" })
map("n", "<leader>x", smart_write_quit(false), { desc = "Smart write and quit current buffer" })
map("n", "<leader>bd", close_current_buffer, { desc = "Delete current buffer" })

vim.api.nvim_create_user_command("SmartQuit", smart_quit(false), {})
vim.api.nvim_create_user_command("SmartQuitForce", smart_quit(true), {})
vim.api.nvim_create_user_command("SmartWrite", smart_write(false), {})
vim.api.nvim_create_user_command("SmartWriteForce", smart_write(true), {})
vim.api.nvim_create_user_command("SmartWriteQuit", smart_write_quit(false), {})
vim.api.nvim_create_user_command("SmartWriteQuitForce", smart_write_quit(true), {})
vim.api.nvim_create_user_command("SmartBdelete", smart_buffer_close(), {})
vim.api.nvim_create_user_command("SmartBwipeout", smart_buffer_wipe(), {})

vim.cmd([[
  cnoreabbrev <expr> q ((getcmdtype() ==# ':' && getcmdline() ==# 'q') ? 'SmartQuit' : 'q')
  cnoreabbrev <expr> quit ((getcmdtype() ==# ':' && getcmdline() ==# 'quit') ? 'SmartQuit' : 'quit')
  cnoreabbrev <expr> q! ((getcmdtype() ==# ':' && getcmdline() ==# 'q!') ? 'SmartQuitForce' : 'q!')
  cnoreabbrev <expr> quit! ((getcmdtype() ==# ':' && getcmdline() ==# 'quit!') ? 'SmartQuitForce' : 'quit!')
  cnoreabbrev <expr> w ((getcmdtype() ==# ':' && getcmdline() ==# 'w') ? 'SmartWrite' : 'w')
  cnoreabbrev <expr> write ((getcmdtype() ==# ':' && getcmdline() ==# 'write') ? 'SmartWrite' : 'write')
  cnoreabbrev <expr> w! ((getcmdtype() ==# ':' && getcmdline() ==# 'w!') ? 'SmartWriteForce' : 'w!')
  cnoreabbrev <expr> write! ((getcmdtype() ==# ':' && getcmdline() ==# 'write!') ? 'SmartWriteForce' : 'write!')
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

-- Windows-style clipboard, limited to the modes where it costs nothing.
-- Normal mode is untouched, so <C-v> is still visual block.
map("x", "<C-c>", '"+y', { desc = "Copy selection" })
map("x", "<C-x>", '"+d', { desc = "Cut selection" })
map("x", "<C-v>", '"+P', { desc = "Paste over selection" })
-- <C-r><C-o>+ pastes verbatim, without re-indenting the pasted lines.
map("i", "<C-v>", "<C-r><C-o>+", { desc = "Paste" })
map("c", "<C-v>", "<C-r>+", { desc = "Paste" })
-- <C-q> keeps the literal-insert that <C-v> used to provide.
map("i", "<C-q>", "<C-v>", { desc = "Insert literal character" })
map("t", "<C-v>", '<C-\\><C-n>"+pi', { desc = "Paste into terminal" })

-- Mouse: IDE-style navigation on top of what 'mouse' already provides.
map("n", "<C-LeftMouse>", "<LeftMouse><Cmd>lua vim.lsp.buf.definition()<CR>", { desc = "Goto definition" })
map("n", "<C-RightMouse>", "<C-o>", { desc = "Jump back" })
-- Side buttons on a mouse walk the jump list, like Back/Forward in a browser.
map("n", "<X1Mouse>", "<C-o>", { desc = "Jump back" })
map("n", "<X2Mouse>", "<C-i>", { desc = "Jump forward" })

-- Project management
map("n", "<leader>pp", projects.pick, { desc = "Open project" })
map("n", "<leader>pm", projects.panel, { desc = "Project panel (mouse)" })
map("n", "<leader>pa", "<cmd>ProjectAdd<CR>", { desc = "Add current project" })
map("n", "<leader>pd", "<cmd>ProjectRemove<CR>", { desc = "Remove current project" })
map("n", "<leader>pr", "<cmd>ProjectRoot<CR>", { desc = "cd to project root" })
map("n", "<leader>pf", projects.in_root("files"), { desc = "Find files in project root" })
map("n", "<leader>pg", projects.in_root("live_grep"), { desc = "Grep in project root" })
map("n", "<leader>ps", "<cmd>ProjectSessionSave<CR>", { desc = "Save project session" })
map("n", "<leader>pl", "<cmd>ProjectSessionLoad<CR>", { desc = "Load project session" })
map("n", "<leader>pD", "<cmd>ProjectSessionDelete<CR>", { desc = "Delete project session" })

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
map("n", "<leader>cv", cmake("CMakeSelectBuildType"), { desc = "CMake build type" })
map("n", "<leader>ck", cmake("CMakeClean"), { desc = "CMake clean" })
map("n", "<leader>cT", cmake("CMakeRunTest"), { desc = "CMake run tests" })
map("n", "<leader>cq", cmake("CMakeStopRunner", "CMakeStopExecutor"), { desc = "CMake stop" })
map("n", "<leader>cn", cmake("CMakeQuickStart"), { desc = "CMake new project" })

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
    if not _G.MiniSurround then
        vim.notify("mini.surround is not loaded", vim.log.levels.WARN)
        return
    end

    MiniSurround.update_n_lines()
end, { desc = "Update surround search lines" })

vim.api.nvim_create_autocmd("LspAttach", {
    callback = set_lsp_keymaps,
})
