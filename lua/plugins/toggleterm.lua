return {
    "akinsho/toggleterm.nvim",
    version = "*",
    cmd = {
        "ToggleTerm",
        "ToggleTermToggleAll",
        "TermExec",
        "TermNew",
        "TermSelect",
    },
    keys = {
        {
            "<leader>t",
            "<cmd>ToggleTerm<cr>",
            desc = "Toggle Terminal",
        },
    },
    opts = {
        direction = "float",
        hide_numbers = true,
        shade_terminals = true,
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        persist_size = true,
        persist_mode = true,
        close_on_exit = true,
        float_opts = {
            border = "curved",
            width = function()
                return math.floor(vim.o.columns * 0.9)
            end,
            height = function()
                return math.floor(vim.o.lines * 0.85)
            end,
            row = function()
                return math.floor((vim.o.lines * 0.15) / 2)
            end,
            col = function()
                return math.floor((vim.o.columns * 0.1) / 2)
            end,
            winblend = 0,
        },
    },
    config = function(_, opts)
        require("toggleterm").setup(opts)

        vim.api.nvim_create_autocmd("TermOpen", {
            pattern = "term://*toggleterm#*",
            callback = function(event)
                local map = function(lhs, rhs)
                    vim.keymap.set("t", lhs, rhs, {
                        buffer = event.buf,
                        silent = true,
                    })
                end

                map("<Esc>", [[<C-\><C-n>]])
                map("<C-h>", [[<Cmd>wincmd h<CR>]])
                map("<C-j>", [[<Cmd>wincmd j<CR>]])
                map("<C-k>", [[<Cmd>wincmd k<CR>]])
                map("<C-l>", [[<Cmd>wincmd l<CR>]])
                map("<C-w>", [[<C-\><C-n><C-w>]])
            end,
        })
    end,
}
