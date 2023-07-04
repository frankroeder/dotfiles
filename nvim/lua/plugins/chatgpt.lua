local utils = require "utils"
local M = {
  "jackMort/ChatGPT.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
}

function M.keys()
  return {
    {
      "<leader>c",
      function()
        require("chatgpt").openChat()
      end,
      desc = "Start ChatGPT",
    },
    {
      "<leader>ce",
      function()
        require("chatgpt").edit_with_instructions()
      end,
      mode = { "n", "v" },
      desc = "Edit with instructions",
    },
    {
      "<leader>cc",
      function()
        require("chatgpt").complete_code()
      end,
      mode = { "n", "v" },
      desc = "Code completion with GPT",
    },
  }
end

function M.config()
  require("chatgpt").setup {
    api_key_cmd = "echo " .. utils.get_openai_token(),
    openai_params = {
      model = "gpt-4",
      frequency_penalty = 0,
      presence_penalty = 0,
      max_tokens = 512,
      temperature = 0.5,
      top_p = 1,
      n = 1,
    },
    openai_edit_params = {
      model = "code-davinci-edit-001",
      temperature = 0.5,
      top_p = 1,
      n = 1,
    },
  }
end
return M
