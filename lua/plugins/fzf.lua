return {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
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
