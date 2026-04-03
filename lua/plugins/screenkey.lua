return {
    "NStefan002/screenkey.nvim",
    lazy = false,
    version = "*", -- or branch = "main", to use the latest commit
    opts = {
        disable = {
            filetypes = { "dashboard", "toggleterm" },
            buftypes = { "terminal" },
        },
    },
    config = function(_, opts)
        local screenkey = require("screenkey")
        local auto_hidden = false

        local function should_hide()
            local filetype = vim.bo.filetype
            return filetype == "dashboard" or filetype == "toggleterm"
        end

        local function sync_screenkey()
            local active = screenkey.is_active()

            if should_hide() then
                if active then
                    screenkey.toggle()
                    auto_hidden = true
                end
                return
            end

            if auto_hidden and not active then
                screenkey.toggle()
                auto_hidden = false
            end
        end

        screenkey.setup(opts)
        screenkey.toggle()

        vim.api.nvim_create_autocmd({ "BufEnter", "FileType", "TermOpen" }, {
            group = vim.api.nvim_create_augroup("ScreenkeyAutoHide", { clear = true }),
            callback = sync_screenkey,
        })

        vim.schedule(sync_screenkey)
    end,
}
