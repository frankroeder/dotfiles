local utils = require "utils"

return {
  "frankroeder/prt.nvim",
  event = "VeryLazy",
  -- enable = false, -- vim.fn.has "macunix" == 1 and vim.fn.expand "$USER" == "frankroeder",
  dev = vim.fn.has "macunix" == 1 and vim.fn.expand "$USER" == "frankroeder",
  lazy = false,
  opts = {
    providers = {
      xai = {
        name = "xai",
        endpoint = "https://api.x.ai/v1/chat/completions",
        api_key = os.getenv "XAI_API_KEY",
        model = {
          "grok-3-beta",
          "grok-3-mini-beta",
        },
      },
      ollama = {
        name = "ollama",
        endpoint = "http://localhost:11434/api/chat",
        api_key = "DUMMY",
        model = "llama3.2:latest",
        headers = {
          ["Content-Type"] = "application/json",
        },
        resolve_api_key = function()
          return true
        end,
        process_stdout = function(response)
          if response:match "message" and response:match "content" then
            local success, content = pcall(vim.json.decode, response)
            if success and content.message and content.message.content then
              return content.message.content
            end
          end
        end,
      },
      -- google = {
      --   name = "google",
      --   endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:streamGenerateContent?alt=sse",
      --   api_key = os.getenv "GEMINI_API_KEY",
      --   model = "gemini-2.0-flash-exp",
      --   headers = function(api_key)
      --     return {
      --       ["Content-Type"] = "application/json",
      --       ["x-goog-api-key"] = api_key,
      --     }
      --   end,
      -- },
      openai = {
        name = "openai",
        api_key = utils.get_api_key("openai-api-key", "OPENAI_API_KEY"),
        endpoint = "https://api.openai.com/v1/chat/completions",
        model = "gpt-4o",
      },
    },
    smooth_delay = 10,
  },
}
