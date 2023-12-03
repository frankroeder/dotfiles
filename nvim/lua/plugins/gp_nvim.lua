local M = {
  "robitx/gp.nvim",
  event = "VeryLazy",
  cond = os.getenv "OPENAI_API_KEY" ~= nil,
}

function M.config()
  local model = "gpt-4-1106-preview"
  local cmd_prefix = "GPT"

  require("gp").setup {
    openai_api_key = os.getenv "OPENAI_API_KEY",
    cmd_prefix = cmd_prefix,
    chat_topic_gen_model = "gpt-3.5-turbo-16k",
    chat_conceal_model_params = false,
    hooks = {
      InspectPlugin = function(plugin, params)
        print(string.format("Plugin structure:\n%s", vim.inspect(plugin)))
        print(string.format("Command params:\n%s", vim.inspect(params)))
      end,
      -- GPTComplete finishes the provided selection/range of code
      -- and appends the result.
      Complete = function(gp, params)
        local template = "I have the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Please finish the code above carefully and logically."
          .. "\n\nRespond just with the snippet of code that should be inserted."
        local agent = gp.get_command_agent()
        gp.Prompt(
          params,
          gp.Target.append,
          nil, -- command will run directly without any prompting for user input
          agent.model,
          template,
          agent.system_prompt
        )
      end,
      Explain = function(gp, params)
        local template = "Explain the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Use markdown format.\n"
          .. "A brief explanation of what the code above is doing:\n"
        local agent = gp.get_chat_agent()
        gp.Prompt(
          params,
          gp.Target.popup,
          nil,
          agent.model,
          template,
          agent.system_prompt
        )
      end,
      FixBugs = function(gp, params)
        local template = "Fix bugs in the below code from {{filename}} carefully and logically:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Fixed code:\n"
        local agent = gp.get_chat_agent()
        gp.Prompt(
          params,
          gp.Target.popup,
          nil,
          agent.model,
          template,
          agent.system_prompt
        )
      end,
      Optimize = function(gp, params)
        local template = "Optimize the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Optimized code:\n"
        local agent = gp.get_chat_agent()
        gp.Prompt(
          params,
          gp.Target.popup,
          nil,
          agent.model,
          template,
          agent.system_prompt
        )
      end,
      UnitTests = function(gp, params)
        local template = "I have the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Please respond by writing table driven unit tests for the code above."
        local agent = gp.get_command_agent()
        gp.Prompt(
          params,
          gp.Target.enew,
          nil,
          agent.model,
          template,
          agent.system_prompt
        )
      end,
      ProofReader = function(gp, params)
        local chat_model = { model = model, temperature = 0.7, top_p = 1 }
        local chat_system_prompt = "I want you act as a proofreader. I will"
          .. "provide you texts and I would like you to review them for any"
          .. "spelling, grammar, or punctuation errors. Once you have finished"
          .. "reviewing the text, provide me with any necessary corrections or"
          .. "suggestions for improve the text. Highlight the corrections with"
          .. "markdown bold or italics style."
        gp.cmd.ChatNew(params, chat_model, chat_system_prompt)
      end,
      Debug = function(gp, params)
        local template = "Imagine you are an expert in {{filetype}}.\n"
          .. "Review the following code, carefully examine it and report"
          .. "potential bugs and edge cases alongside solutions to resolve them:"
          .. "```{{filetype}}{{selection}}\n```\n\n"
        local agent = gp.get_command_agent()
        gp.Prompt(
          params,
          gp.Target.enew,
          nil,
          agent.model,
          template,
          agent.system_prompt
        )
      end,
    },
  }
  local unused_commands = {
    "Whisper",
    "WhisperRewrite",
    "WhisperAppend",
    "WhisperPrepend",
    "WhisperEnew",
    "WhisperPopup",
  }
  for _, command in ipairs(unused_commands) do
    vim.api.nvim_del_user_command(cmd_prefix .. command)
  end
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
