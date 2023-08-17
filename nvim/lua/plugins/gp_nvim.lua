local M = {
  "robitx/gp.nvim",
  event = "VeryLazy",
  cond = os.getenv "OPENAI_API_KEY" ~= nil,
}

function M.opts()
  return {
    openai_api_key = os.getenv "OPENAI_API_KEY",
    chat_topic_gen_model = "gpt-3.5-turbo-16k",
    hooks = {
      InspectPlugin = function(plugin, params)
        print(string.format("Plugin structure:\n%s", vim.inspect(plugin)))
        print(string.format("Command params:\n%s", vim.inspect(params)))
      end,
      -- GpImplement finishes the provided selection/range based on comments in the code
      Implement = function(gp, params)
        local template = "I have the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Please finish the code above according to comment instructions."
          .. "\n\nRespond just with the snippet of code that should be inserted."

        gp.Prompt(
          params,
          gp.Target.rewrite,
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
          .. "Explanation of what the code above is doing:\n"

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
        local template = "Fix bugs in the below code from {{filename}}:\n\n"
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
      "<cmd>GpChatNew<cr>",
      mode = { "n", "i" },
      desc = "New Chat",
    },
    {
      "<C-g>t",
      "<cmd>GpChatToggle<cr>",
      mode = { "n", "i" },
      desc = "Toggle Popup Chat",
    },
    {
      "<C-g>f",
      "<cmd>GpChatFinder<cr>",
      mode = { "n", "i" },
      desc = "Chat Finder",
    },
    {
      "<C-g>r",
      "<cmd>GpRewrite<cr>",
      mode = { "n", "i" },
      desc = "Inline Rewrite",
    },
    {
      "<C-g>a",
      "<cmd>GpAppend<cr>",
      mode = { "n", "i" },
      desc = "Append",
    },
    {
      "<C-g>b",
      "<cmd>GpPrepend<cr>",
      mode = { "n", "i" },
      desc = "Prepend",
    },
    {
      "<C-g>e",
      "<cmd>GpEnew<cr>",
      mode = { "n", "i" },
      desc = "Enew",
    },
    {
      "<C-g>p",
      "<cmd>GpPopup<cr>",
      mode = { "n", "i" },
      desc = "Popup",
    },
    {
      "<C-g>c",
      ":<C-u>'<,'>GpChatNew<cr>",
      mode = { "v" },
      desc = "Visual Chat New",
    },
    {
      "<C-g>t",
      ":<C-u>'<,'>GpChatToggle<cr>",
      mode = { "v" },
      desc = "Visual Popup Chat",
    },
    {
      "<C-g>r",
      ":<C-u>'<,'>GpRewrite<cr>",
      mode = { "v" },
      desc = "Visual Rewrite",
    },
    {
      "<C-g>a",
      ":<C-u>'<,'>GpAppend<cr>",
      mode = { "v" },
      desc = "Visual Append",
    },
    {
      "<C-g>b",
      ":<C-u>'<,'>GpPrepend<cr>",
      mode = { "v" },
      desc = "Visual Prepend",
    },
    {
      "<C-g>e",
      ":<C-u>'<,'>GpEnew<cr>",
      mode = { "v" },
      desc = "Visual Enew",
    },
    {
      "<C-g>p",
      ":<C-u>'<,'>GpPopup<cr>",
      mode = { "v" },
      desc = "Visual Popup",
    },
    {
      "<C-g>s",
      "<cmd>GpStop<cr>",
      mode = { "n", "i", "v", "x" },
      desc = "Stop",
    },
  }
end

return M
