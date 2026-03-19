return {
  "greggh/claude-code.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("claude-code").setup({
      window = {
        split_ratio = 0.3,      -- 30% of screen
        position = "botright",   -- bottom right
        enter_insert = true      -- start in insert mode
      },
      keymaps = {
        toggle = {
          normal = "<C-,>",      -- Ctrl+, to toggle
          terminal = "<C-,>"
        }
      }
    })
  end
}