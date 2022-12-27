local M = {
  "lewis6991/gitsigns.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "BufRead",
  cond = function()
    return vim.loop.fs_stat(".git")
  end,
}

function M.config()
  require("gitsigns").setup {
    signs = {
      add = {
        hl = "GitSignsAdd",
        text = "+",
        numhl = "GitSignsAddNr",
        linehl = "GitSignsAddLn",
      },
      change = {
        hl = "GitSignsChange",
        text = "~",
        numhl = "GitSignsChangeNr",
        linehl = "GitSignsChangeLn",
      },
      delete = {
        hl = "GitSignsDelete",
        text = "_",
        numhl = "GitSignsDeleteNr",
        linehl = "GitSignsDeleteLn",
      },
      topdelete = {
        hl = "GitSignsDelete",
        text = "‾",
        numhl = "GitSignsDeleteNr",
        linehl = "GitSignsDeleteLn",
      },
      changedelete = {
        hl = "GitSignsChange",
        text = "~",
        numhl = "GitSignsChangeNr",
        linehl = "GitSignsChangeLn",
      },
    },
    keymaps = {
      noremap = true,
      ["n <Leader>gm"] = '<cmd>lua require"gitsigns".preview_hunk()<CR>',
    },
    max_file_length = 2000,
  }
end

return M
