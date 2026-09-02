-- flash.nvim: modern successor to vim-easymotion
-- Jump anywhere with `s` + chars, then a label; treesitter-aware selection with `S`
vim.pack.add { 'https://github.com/folke/flash.nvim' }

require('flash').setup {
  modes = {
    search = {
      enabled = false, -- keep normal `/` search behavior
    },
  },
}

-- `s` jumps anywhere, `S` does treesitter-aware selection
vim.keymap.set({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = 'Flash' })
vim.keymap.set({ 'n', 'x', 'o' }, 'S', function() require('flash').treesitter() end, { desc = 'Flash Treesitter' })
