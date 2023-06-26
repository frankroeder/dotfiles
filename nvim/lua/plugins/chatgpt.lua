local utils = require("utils")
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
        vim.cmd [[ChatGPT]]
      end,
      desc = "Start ChatGPT",
    },
    {
      "<leader>ce",
      function()
        vim.cmd [[ChatGPTEditWithInstructions]]
      end,
      mode = { "n", "v" },
      desc = "Edit with instructions",
    },
    {
      "<leader>cc",
      function()
        vim.cmd [[ChatGPTCompleteCode]]
      end,
      mode = { "n", "v" },
      desc = "Code completion with ChatGPT",
    },
  }
end

function M.config()
  require("chatgpt").setup {
    api_key_cmd = "echo " .. utils.get_openai_token(),
    openai_params = {
      -- model = "gpt-3.5-turbo",
      model = "gpt-4",
      frequency_penalty = 0,
      presence_penalty = 0,
      max_tokens = 300,
      temperature = 0,
      top_p = 1,
      n = 1,
    },
  }
end

return M
