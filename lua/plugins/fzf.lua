return {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    keys = {
        "<leader>ff",
        "<leader>fg",
        "<leader>fw",
        "<leader>fb",
        "<leader>fo",
        "<leader>fh",
        "<leader>ld",
        "<leader>lr",
        "<leader>li",
        "<leader>lt",
        "<leader>ls",
        "<leader>lS",
        "<leader>lx",
        "<leader>lq",
        "<leader>gf",
        "<leader>gs",
        "<leader>gc",
        "<leader>gb",
        "<leader>gh",
    },
    dependencies = {
        { "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font ~= false },
    },
    opts = {
        winopts = {
            border = "rounded",
            preview = {
                border = "rounded",
                layout = "vertical",
                vertical = "down:55%",
            },
        },
        files = {
            hidden = true,
            cwd_prompt = false,
            rg_opts = "--color=never --files --hidden -g !.git",
        },
        grep = {
            hidden = true,
            rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden -g !.git -e",
        },
    },
}
