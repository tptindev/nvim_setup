return {
    "nvim-treesitter/nvim-treesitter",
    -- The config below uses the `main` branch API (`setup`/`install`), which is
    -- not what the legacy `master` branch exposes. Pin it explicitly.
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local languages = {
            "c",
            "cpp",
            "cmake",
            "glsl",
            "lua",
            "luadoc",
            "json",
            "query",
            "vim",
            "vimdoc",
            "comment",
            "markdown",
            "markdown_inline",
            "bash",
            "diff",
            "gitcommit",
        }

        local indent_filetypes = {
            c = true,
            cpp = true,
            cmake = true,
            glsl = true,
            lua = true,
        }

        local fold_filetypes = {
            c = true,
            cpp = true,
            cmake = true,
            glsl = true,
            lua = true,
        }

        local ts = require("nvim-treesitter")
        ts.setup()

        local function missing_parsers()
            local installed = {}
            for _, name in ipairs(ts.get_installed("parsers")) do
                installed[name] = true
            end

            return vim.tbl_filter(function(lang)
                if installed[lang] then
                    return false
                end

                -- Neovim bundles c/lua/markdown/query/vim/vimdoc in its own
                -- runtime, which is not the nvim-treesitter install dir.
                return vim.tbl_isempty(vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false))
            end, languages)
        end

        -- `main` compiles every parser through the tree-sitter CLI. Without it
        -- each startup prints a wall of ENOENT errors, so ask instead of failing.
        -- mason-tool-installer provides `tree-sitter-cli`.
        local function install_missing(notify_when_idle)
            local pending = missing_parsers()

            if vim.tbl_isempty(pending) then
                if notify_when_idle then
                    vim.notify("Treesitter: all parsers installed", vim.log.levels.INFO)
                end
                return
            end

            if vim.fn.executable("tree-sitter") ~= 1 then
                vim.notify(
                    ("Treesitter: %d parser(s) missing (%s) but the `tree-sitter` CLI was not found.\n")
                    :format(#pending, table.concat(pending, ", "))
                    .. "Run :MasonInstall tree-sitter-cli, restart, then :TSEnsure.",
                    vim.log.levels.WARN
                )
                return
            end

            ts.install(pending)
        end

        vim.api.nvim_create_user_command("TSEnsure", function()
            install_missing(true)
        end, { desc = "Install any missing Treesitter parser" })

        -- Defer past startup so mason has a chance to put tree-sitter on $PATH.
        vim.api.nvim_create_autocmd("VimEnter", {
            once = true,
            callback = function()
                vim.defer_fn(function()
                    install_missing(false)
                end, 1000)
            end,
        })

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "*",
            callback = function(args)
                local buf = args.buf
                if not vim.api.nvim_buf_is_valid(buf) then
                    return
                end

                if not pcall(vim.treesitter.start, buf) then
                    return
                end

                local filetype = vim.bo[buf].filetype

                if indent_filetypes[filetype] then
                    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end

                if fold_filetypes[filetype] then
                    local win = vim.api.nvim_get_current_win()
                    if vim.api.nvim_win_get_buf(win) == buf then
                        vim.wo[win][0].foldmethod = "expr"
                        vim.wo[win][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
                    end
                end
            end,
        })
    end,
}
