local M = {
  "stevearc/aerial.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
}

function M.config()
  local status_ok, aerial = pcall(require, "aerial")
  if not status_ok then
    return
  end

  aerial.setup {
    backends = { "treesitter", "lsp", "markdown", "man" },
    default_direction = "prefer_right",
    ignore = {
      filetypes = { "tex" },
    },
  }
  vim.keymap.set("n", "<Leader>a", "<cmd>AerialToggle!<CR>")
  if vim.fn.executable "fzf" == 1 then
    vim.keymap.set("n", "<Leader>p", [[<cmd>call aerial#fzf()<CR>]])
  end
end

return M
