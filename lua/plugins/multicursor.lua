return {
    "jake-stewart/multicursor.nvim",
    -- `main` and `1.0` currently point at the same commit, but the author
    -- documents `1.0` as the stable branch, so pin that instead of tracking
    -- whatever lands on main.
    branch = "1.0",
    event = "VeryLazy",
    config = function()
        local mc = require("multicursor-nvim")
        mc.setup()

        -- A keymap layer is only installed while more than one cursor exists,
        -- so these keys keep their usual meaning the rest of the time. In
        -- particular `<Esc>` must not be grabbed globally: it is what leaves
        -- insert mode, dismisses floats and exits the toggleterm window.
        mc.addKeymapLayer(function(layer)
            layer({ "n", "x" }, "<C-Left>", mc.prevCursor, { desc = "Previous cursor" })
            layer({ "n", "x" }, "<C-Right>", mc.nextCursor, { desc = "Next cursor" })
            layer({ "n", "x" }, "<leader>mx", mc.deleteCursor, { desc = "Delete current cursor" })
            -- One `<Esc>` re-enables cursors that `<leader>mt` disabled, the
            -- next one collapses everything back to a single cursor.
            layer("n", "<Esc>", function()
                if mc.cursorsEnabled() then
                    mc.clearCursors()
                else
                    mc.enableCursors()
                end
            end, { desc = "Clear cursors" })
        end)
    end,
}
