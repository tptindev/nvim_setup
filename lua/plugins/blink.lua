return {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = {
        "rafamadriz/friendly-snippets",
    },
    opts = {
        keymap = {
            preset = "super-tab",
        },
        appearance = {
            nerd_font_variant = "mono",
        },
        completion = {
            documentation = {
                auto_show = true,
                auto_show_delay_ms = 200,
            },
        },
        signature = {
            enabled = true,
        },
        sources = {
            -- lazydev only yields completions in Lua buffers; the high
            -- score_offset keeps its `require("...")` paths above the LSP's own
            -- (worse) guesses instead of below them.
            default = { "lsp", "path", "snippets", "buffer", "lazydev" },
            providers = {
                lazydev = {
                    name = "LazyDev",
                    module = "lazydev.integrations.blink",
                    score_offset = 100,
                },
            },
        },
        fuzzy = {
            implementation = "prefer_rust_with_warning",
        },
    },
    opts_extend = { "sources.default" },
}
