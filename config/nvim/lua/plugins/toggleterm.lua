return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    require("toggleterm").setup({
      size = 20,
      open_mapping = [[<c-\>]],
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = true,
      persist_mode = true,
      direction = 'float', -- 'vertical' | 'horizontal' | 'tab' | 'float'
      close_on_exit = true,
      shell = vim.o.shell,
      auto_scroll = true,
      float_opts = {
        border = 'curved',
        winblend = 0,
        highlights = {
          border = "Normal",
          background = "Normal",
        }
      }
    })

    -- Custom terminal functions
    local Terminal = require('toggleterm.terminal').Terminal

    -- Lazygit terminal
    local lazygit = Terminal:new({
      cmd = "lazygit",
      dir = "git_dir",
      direction = "float",
      float_opts = {
        border = "double",
      },
      hidden = true,
    })

    function _lazygit_toggle()
      lazygit:toggle()
    end

    -- Horizontal terminal
    function _horizontal_toggle()
      local term = Terminal:new({ direction = "horizontal", hidden = true })
      term:toggle()
    end

    -- Vertical terminal
    function _vertical_toggle()
      local term = Terminal:new({ direction = "vertical", hidden = true })
      term:toggle()
    end

    -- Key mappings
    vim.api.nvim_set_keymap("n", "<leader>gg", "<cmd>lua _lazygit_toggle()<CR>", {noremap = true, silent = true, desc = "Toggle Lazygit"})
    vim.api.nvim_set_keymap("n", "<leader>th", "<cmd>lua _horizontal_toggle()<CR>", {noremap = true, silent = true, desc = "Toggle Horizontal Terminal"})
    vim.api.nvim_set_keymap("n", "<leader>tv", "<cmd>lua _vertical_toggle()<CR>", {noremap = true, silent = true, desc = "Toggle Vertical Terminal"})
    vim.api.nvim_set_keymap("n", "<leader>tf", "<cmd>ToggleTerm direction=float<CR>", {noremap = true, silent = true, desc = "Toggle Float Terminal"})

    -- Terminal mode mappings
    function _G.set_terminal_keymaps()
      local opts = {buffer = 0}
      vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts)
      vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
      vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
      vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
      vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
      vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts)
    end

    -- Auto command to set terminal keymaps
    vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')
  end
}