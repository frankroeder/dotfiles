local M = {
  "jackMort/ChatGPT.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
}

function M.config()
  require("chatgpt").setup {
    api_key_cmd = "security find-generic-password -s openai-api-key -w",
    openai_params = {
      model = "gpt-4",
    },
  }
end

return M
