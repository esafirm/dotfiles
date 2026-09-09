-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
}

vim.keymap.set('n', '\\', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })
vim.keymap.set('n', '<leader>gs', '<Cmd>Neotree git_status reveal<CR>', { desc = 'NeoTree [G]it [S]tatus', silent = true })
vim.keymap.set('n', '<D-S-g>', '<Cmd>Neotree git_status reveal<CR>', { desc = 'NeoTree [G]it [S]tatus', silent = true })
vim.keymap.set('n', '<D-G>', '<Cmd>Neotree git_status reveal<CR>', { desc = 'NeoTree [G]it [S]tatus', silent = true })

require('neo-tree').setup {
  window = {
    width = 32, -- default 40, slimmed ~20%
  },
  filesystem = {
    window = {
      mappings = {
        ['\\'] = 'close_window',
      },
    },
  },
}
