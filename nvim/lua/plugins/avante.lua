return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  build = ":AvanteBuild",
  lazy = false,
  cmd = { "AvanteAsk" },
  opts = {
    provider = "claude",
    claude = {
      api_key_name = "cmd:/usr/bin/security find-generic-password -s anthropic-api-key -w",
      temperature = 0.7,
    },
    openai = {
      api_key_name = "cmd:/usr/bin/security find-generic-password -s openai-api-key -w",
      temperature = 0.7,
    },
    hints = { enabled = false },
  },
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "MeanderingProgrammer/render-markdown.nvim",
  },
}
