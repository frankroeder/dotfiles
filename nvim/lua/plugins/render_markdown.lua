local M = {
  "MeanderingProgrammer/markdown.nvim",
  main = "render-markdown",
  name = "render-markdown",
  opts = {},
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
}

function M.config()
  require("render-markdown").setup()
  vim.keymap.set("n", "<Space>tt", "<cmd>RenderMarkdown toggle<CR>")
end
return M
