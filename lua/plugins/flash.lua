return {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    config = function(_, opts)
        -- flash's hacks.lua reads Neovim's internal `Search` struct via LuaJIT FFI
        -- (added for nvim-0.13 search-state support, upstream commit 7eff7f8). Windows
        -- nvim.exe does not export that global through GetProcAddress the way Linux/mac
        -- builds do, so every FFI call throws "cannot resolve symbol 'Search'" and
        -- crashes the jump. Wrap each entry point in pcall and degrade instead of erroring.
        local hacks = require("flash.hacks")
        local get_end_pos = hacks.get_end_pos
        hacks.get_end_pos = function(from)
            local ok, ret = pcall(get_end_pos, from)
            return ok and ret or from
        end
        local save_incsearch_state = hacks.save_incsearch_state
        hacks.save_incsearch_state = function(...)
            pcall(save_incsearch_state, ...)
        end
        local restore_incsearch_state = hacks.restore_incsearch_state
        hacks.restore_incsearch_state = function(...)
            pcall(restore_incsearch_state, ...)
        end
        local mappings_enabled = hacks.mappings_enabled
        hacks.mappings_enabled = function(...)
            local ok, ret = pcall(mappings_enabled, ...)
            if ok then
                return ret
            end
            return true
        end

        require("flash").setup(opts)
    end,
}
