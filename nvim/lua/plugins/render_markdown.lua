return {
  "MeanderingProgrammer/markdown.nvim",
  name = "render-markdown",
  lazy = false,
  opts = {},
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<Space>tt", "<cmd>RenderMarkdown toggle<CR>" },
  },
}
