-- lua_ls only knows the `vim` API if its workspace.library points at Neovim's
-- runtime and at every plugin's type annotations. Listing them statically makes
-- lua_ls index the whole lazy.nvim plugin directory on the first Lua buffer;
-- lazydev adds a path only once a `require`/`vim.uv` mention needs it.
return {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
        library = {
            -- vim.uv is typed by the luv meta file, which is not in the runtime
            -- path and so is never picked up on its own.
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
    },
}
