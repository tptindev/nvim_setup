return {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        signs = {
            add = { text = "┃" },
            change = { text = "┃" },
            delete = { text = "▁" },
            topdelete = { text = "▔" },
            changedelete = { text = "~" },
            untracked = { text = "┆" },
        },
        -- Off by default: the virtual text moves while you type. `<leader>gB`
        -- turns it on for as long as it is useful.
        current_line_blame = false,
        current_line_blame_opts = {
            virt_text_pos = "eol",
            delay = 300,
            ignore_whitespace = true,
        },
        preview_config = {
            border = "rounded",
        },
        on_attach = function(buf)
            local gs = require("gitsigns")

            local function map(mode, lhs, rhs, desc)
                vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
            end

            -- `]c` / `[c` are Vim's own diff motions. Keep them when the window
            -- really is in diff mode (`:Gitsigns diffthis`, `:diffsplit`) and
            -- only stand in for them when it is an ordinary buffer.
            map("n", "]c", function()
                if vim.wo.diff then
                    vim.cmd.normal({ "]c", bang = true })
                else
                    gs.nav_hunk("next")
                end
            end, "Next hunk")

            map("n", "[c", function()
                if vim.wo.diff then
                    vim.cmd.normal({ "[c", bang = true })
                else
                    gs.nav_hunk("prev")
                end
            end, "Previous hunk")

            -- `<leader>gf/gs/gc/gb/gh` already belong to the fzf-lua pickers in
            -- keymaps.lua, so the hunk actions take the letters left over.
            map("n", "<leader>ga", gs.stage_hunk, "Stage hunk (toggles on a staged hunk)")
            map("v", "<leader>ga", function()
                gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
            end, "Stage selected lines")
            map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
            map("v", "<leader>gr", function()
                gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
            end, "Reset selected lines")
            map("n", "<leader>gA", gs.stage_buffer, "Stage buffer")
            map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")

            map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
            map("n", "<leader>gl", function()
                gs.blame_line({ full = true })
            end, "Blame line")
            map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle line blame")
            map("n", "<leader>gd", gs.diffthis, "Diff against index")
            map("n", "<leader>gD", function()
                gs.diffthis("~")
            end, "Diff against last commit")

            map({ "o", "x" }, "ih", gs.select_hunk, "Hunk")
        end,
    },
}
