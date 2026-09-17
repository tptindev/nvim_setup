return {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        formatters = {
            -- clang-format picks its language from the file extension and does
            -- not know .vert/.frag/.comp, so tell it to treat them as C.
            clang_format_glsl = {
                command = "clang-format",
                args = { "--assume-filename=shader.c", "-" },
                stdin = true,
            },
            -- cmake-format ships with the `cmakelang` package; skip quietly
            -- rather than erroring on every save when it is not installed.
            cmake_format = {
                condition = function()
                    return vim.fn.executable("cmake-format") == 1
                end,
            },
        },
        formatters_by_ft = {
            lua = { "stylua" },
            c = { "clang-format" },
            cpp = { "clang-format" },
            glsl = { "clang_format_glsl" },
            cmake = { "cmake_format" },
        },
        default_format_opts = {
            lsp_format = "fallback",
        },
        format_on_save = function(bufnr)
            -- Respect a per-buffer / global opt-out: :lua vim.g.disable_autoformat = true
            if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                return
            end

            local supported = {
                lua = true,
                c = true,
                cpp = true,
                glsl = true,
                cmake = true,
            }

            if not supported[vim.bo[bufnr].filetype] then
                return
            end

            return {
                timeout_ms = 2000,
                lsp_format = "fallback",
            }
        end,
    },
    init = function()
        vim.api.nvim_create_user_command("FormatToggle", function(args)
            local global = args.bang ~= true
            if global then
                vim.g.disable_autoformat = not vim.g.disable_autoformat
                vim.notify("Format on save: " .. (vim.g.disable_autoformat and "off" or "on"))
            else
                vim.b.disable_autoformat = not vim.b.disable_autoformat
                vim.notify("Format on save (buffer): " .. (vim.b.disable_autoformat and "off" or "on"))
            end
        end, { bang = true, desc = "Toggle format on save (! for this buffer only)" })
    end,
}
