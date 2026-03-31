local function fzf(picker, opts)
    return function()
        require("fzf-lua")[picker](opts or {})
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
