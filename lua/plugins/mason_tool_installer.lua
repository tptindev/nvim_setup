return {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = {
        "mason.nvim",
    },
    opts = {
        ensure_installed = {
            "stylua",
            "clang-format",
        },
    },
}
