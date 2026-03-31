return {
    "Civitasv/cmake-tools.nvim",
    cmd = {
        "CMakeGenerate",
        "CMakeBuild",
        "CMakeRun",
        "CMakeSelectBuildTarget",
        "CMakeSelectLaunchTarget",
        "CMakeSelectConfigurePreset",
        "CMakeSelectKit",
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
        cmake_soft_link_compile_commands = true,
    },
    config = function(_, opts)
        require("cmake-tools").setup(opts)
    end,
}
