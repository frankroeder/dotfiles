return {
  "MeanderingProgrammer/render-markdown.nvim",
  lazy = false,
  opts = {
    anti_conceal = {
      enabled = true,
    },
    win_options = {
      conceallevel = {
        default = 0,
        -- default = vim.api.nvim_get_option_value('conceallevel', {}),
        rendered = 3,
      },
      concealcursor = {
        default = vim.api.nvim_get_option_value("concealcursor", {}),
        rendered = "",
      },
    },
    file_types = { "markdown", "Avante" },
  },
  ft = { "markdown", "Avante" },
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<Space>tt", "<cmd>RenderMarkdown toggle<CR>" },
  },
}
