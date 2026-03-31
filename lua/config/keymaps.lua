local function fzf(picker, opts)
    return function()
        require("fzf-lua")[picker](opts or {})
    end
end

vim.keymap.set("n", "<leader>ff", fzf("files"), { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", fzf("live_grep"), { desc = "Live grep" })
vim.keymap.set("n", "<leader>fw", fzf("grep_cword"), { desc = "Grep current word" })
vim.keymap.set("n", "<leader>fb", fzf("buffers"), { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fo", fzf("oldfiles"), { desc = "Find old files" })
vim.keymap.set("n", "<leader>fh", fzf("help_tags"), { desc = "Help tags" })

vim.keymap.set("n", "<leader>ld", fzf("lsp_definitions"), { desc = "LSP definitions" })
vim.keymap.set("n", "<leader>lr", fzf("lsp_references"), { desc = "LSP references" })
vim.keymap.set("n", "<leader>li", fzf("lsp_implementations"), { desc = "LSP implementations" })
vim.keymap.set("n", "<leader>lt", fzf("lsp_typedefs"), { desc = "LSP typedefs" })
vim.keymap.set("n", "<leader>ls", fzf("lsp_document_symbols"), { desc = "Document symbols" })
vim.keymap.set("n", "<leader>lS", fzf("lsp_live_workspace_symbols"), { desc = "Workspace symbols" })
vim.keymap.set("n", "<leader>lx", fzf("diagnostics_document"), { desc = "Document diagnostics" })
vim.keymap.set("n", "<leader>lq", fzf("quickfix"), { desc = "Quickfix list" })

vim.keymap.set("n", "<leader>gf", fzf("git_files"), { desc = "Git files" })
vim.keymap.set("n", "<leader>gs", fzf("git_status"), { desc = "Git status" })
vim.keymap.set("n", "<leader>gc", fzf("git_commits"), { desc = "Git commits" })
vim.keymap.set("n", "<leader>gb", fzf("git_branches"), { desc = "Git branches" })
vim.keymap.set("n", "<leader>gh", fzf("git_bcommits"), { desc = "Git file history" })

vim.keymap.set("n", "<Leader>;", function()
    require("dropbar.api").pick()
end, { desc = "Pick symbols in winbar" })

vim.keymap.set("n", "[;", function()
    require("dropbar.api").goto_context_start()
end, { desc = "Go to start of current context" })

vim.keymap.set("n", "];", function()
    require("dropbar.api").select_next_context()
end, { desc = "Select next context" })
