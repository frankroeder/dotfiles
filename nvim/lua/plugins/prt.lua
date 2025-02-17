local utils = require "utils"

return {
  "frankroeder/prt.nvim",
  event = "VeryLazy",
  dev = true,
  lazy = false,
  opts = {
    provider = {
      name = "openai",
      api_key = utils.get_api_key("openai-api-key", "OPENAI_API_KEY"),
      endpoint = "https://api.openai.com/v1/chat/completions",
      model = "gpt-4o",
    },
    -- provider = {
    --   name = "xai",
    --   endpoint = "https://api.x.ai/v1/chat/completions",
    --   api_key = os.getenv "XAI_API_KEY",
    --   model = "grok-2",
    -- },
    -- provider = {
    --   name = "anthropic",
    --   api_key = utils.get_api_key("anthropic-api-key", "ANTHROPIC_API_KEY"),
    --   endpoint = "https://api.openai.com/v1/chat/completions",
    --   model = "claude-3-5-sonnet-latest",
    --   preprocess_payload = function(payload)
    --     for _, message in ipairs(payload.messages) do
    --       message.content = message.content:gsub("^%s*(.-)%s*$", "%1")
    --     end
    --     if payload.messages[1] and payload.messages[1].role == "system" then
    --       -- remove the first message that serves as the system prompt as anthropic
    --       -- expects the system prompt to be part of the API call body and not the messages
    --       payload.system = payload.messages[1].content
    --       table.remove(payload.messages, 1)
    --     end
    --     return payload
    --   end,
    --   process_stdout = function(response)
    --     if response:match "content_block_delta" and response:match "text_delta" then
    --       local success, decoded_line = pcall(vim.json.decode, response)
    --       if
    --         success
    --         and decoded_line.delta
    --         and decoded_line.delta.type == "text_delta"
    --         and decoded_line.delta.text
    --       then
    --         return decoded_line.delta.text
    --       end
    --     end
    --     return nil
    --   end,
    -- },
    smooth_delay = 10,
  },
}
