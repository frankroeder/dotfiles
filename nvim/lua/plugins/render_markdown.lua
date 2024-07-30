return {
  "MeanderingProgrammer/markdown.nvim",
  main = "render-markdown",
  name = "render-markdown",
  opts = {},
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
  init = function()
    require("render-markdown").enable()
  end,
  keys = {
    { "<Space>tt", "<cmd>RenderMarkdown toggle<CR>" },
  },
}
