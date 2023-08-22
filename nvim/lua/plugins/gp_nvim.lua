local M = {
  "robitx/gp.nvim",
  event = "VeryLazy",
  cond = os.getenv "OPENAI_API_KEY" ~= nil,
}

function M.opts()
  return {
    openai_api_key = os.getenv "OPENAI_API_KEY",
    cmd_prefix = "GPT",
    chat_topic_gen_model = "gpt-3.5-turbo-16k",
    hooks = {
      InspectPlugin = function(plugin, params)
        print(string.format("Plugin structure:\n%s", vim.inspect(plugin)))
        print(string.format("Command params:\n%s", vim.inspect(params)))
      end,
      -- GPTCompelte finishes the provided selection/range of code
      -- and appends the result.
      Complete = function(gp, params)
        local template = "I have the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Please finish the code above carefully and logically."
          .. "\n\nRespond just with the snippet of code that should be inserted."

        gp.Prompt(
          params,
          gp.Target.append,
          nil, -- command will run directly without any prompting for user input
          gp.config.command_model,
          template,
          gp.config.command_system_prompt
        )
      end,
      Explain = function(gp, params)
        local template = "Explain the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Use markdown format\n"
          .. "Explanation of what the code above is doing, think carefully and logically:\n"

        gp.Prompt(
          params,
          gp.Target.popup,
          nil, -- command will run directly without any prompting for user input
          gp.config.command_model,
          template,
          gp.config.chat_system_prompt
        )
      end,
      FixBugs = function(gp, params)
        local template = "Fix bugs in the below code from {{filename}} carefully and logically:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Fixed code:\n"

        gp.Prompt(
          params,
          gp.Target.popup,
          nil, -- command will run directly without any prompting for user input
          gp.config.command_model,
          template,
          gp.config.chat_system_prompt
        )
      end,
    },
  }
end

function M.keys()
  return {
    {
      "<C-g>c",
      "<cmd>GPTChatNew<cr>",
      mode = { "n", "i" },
      desc = "New Chat",
    },
    {
      "<C-g>t",
      "<cmd>GPTChatToggle<cr>",
      mode = { "n", "i" },
      desc = "Toggle Popup Chat",
    },
    {
      "<C-g>f",
      "<cmd>GPTChatFinder<cr>",
      mode = { "n", "i" },
      desc = "Chat Finder",
    },
    {
      "<C-g>r",
      "<cmd>GPTRewrite<cr>",
      mode = { "n", "i" },
      desc = "Inline Rewrite",
    },
    {
      "<C-g>a",
      "<cmd>GPTAppend<cr>",
      mode = { "n", "i" },
      desc = "Append",
    },
    {
      "<C-g>o",
      "<cmd>GPTPrepend<cr>",
      mode = { "n", "i" },
      desc = "Prepend",
    },
    {
      "<C-g>e",
      "<cmd>GPTEnew<cr>",
      mode = { "n", "i" },
      desc = "Enew",
    },
    {
      "<C-g>p",
      "<cmd>GPTPopup<cr>",
      mode = { "n", "i" },
      desc = "Popup",
    },
    {
      "<C-g>c",
      ":<C-u>'<,'>GPTChatNew<cr>",
      mode = { "v" },
      desc = "Visual Chat New",
    },
    {
      "<C-g>t",
      ":<C-u>'<,'>GPTChatToggle<cr>",
      mode = { "v" },
      desc = "Visual Popup Chat",
    },
    {
      "<C-g>r",
      ":<C-u>'<,'>GPTRewrite<cr>",
      mode = { "v" },
      desc = "Visual Rewrite",
    },
    {
      "<C-g>a",
      ":<C-u>'<,'>GPTAppend<cr>",
      mode = { "v" },
      desc = "Visual Append",
    },
    {
      "<C-g>o",
      ":<C-u>'<,'>GPTPrepend<cr>",
      mode = { "v" },
      desc = "Visual Prepend",
    },
    {
      "<C-g>e",
      ":<C-u>'<,'>GPTEnew<cr>",
      mode = { "v" },
      desc = "Visual Enew",
    },
    {
      "<C-g>p",
      ":<C-u>'<,'>GPTPopup<cr>",
      mode = { "v" },
      desc = "Visual Popup",
    },
    {
      "<C-g>s",
      "<cmd>GPTStop<cr>",
      mode = { "n", "i", "v", "x" },
      desc = "Stop",
    },
    {
      "<C-g>i",
      ":<C-u>'<,'>GPTComplete<cr>",
      mode = { "n", "i", "v", "x" },
      desc = "Complete the visual selection",
    },
  }
end

return M
