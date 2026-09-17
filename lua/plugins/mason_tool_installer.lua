return {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = {
        "mason.nvim",
    },
    opts = {
        ensure_installed = {
            "stylua",
            "clang-format",
            -- nvim-treesitter (main branch) shells out to this to compile parsers.
            "tree-sitter-cli",
            -- provides `cmake-format` for CMakeLists.txt
            "cmakelang",
        },
    },
}
