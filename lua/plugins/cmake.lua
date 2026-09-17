return {
    "Civitasv/cmake-tools.nvim",
    cmd = {
        "CMakeGenerate",
        "CMakeBuild",
        "CMakeRun",
        "CMakeClean",
        "CMakeRunTest",
        "CMakeQuickStart",
        "CMakeSelectBuildType",
        "CMakeSelectBuildTarget",
        "CMakeSelectLaunchTarget",
        "CMakeSelectConfigurePreset",
        "CMakeSelectKit",
        "CMakeStopRunner",
        "CMakeStopExecutor",
    },
    ft = { "c", "cpp", "cmake" },
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    opts = {
        cmake_command = "cmake",
        cmake_regenerate_on_save = false,
        cmake_build_directory = "build/${variant:buildType}",
        cmake_generate_options = {
            "-DCMAKE_EXPORT_COMPILE_COMMANDS=1",
        },
        cmake_use_preset = true,
        -- Windows cannot create compile_commands.json symlinks without admin rights.
        -- Copy the file to cwd so clangd can discover it via root_markers.
        cmake_compile_commands_options = {
            action = "copy",
            target = function()
                return vim.fn.getcwd()
            end,
        },
        cmake_runner = {
            name = "toggleterm",
            opts = {
                direction = "float",
                close_on_exit = false,
                auto_scroll = true,
                auto_focus = true,
                singleton = true,
            },
        },
    },
    config = function(_, opts)
        require("cmake-tools").setup(opts)
    end,
}
