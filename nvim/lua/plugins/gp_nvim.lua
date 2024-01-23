local M = {
  "frankroeder/gp.nvim",
  event = "VeryLazy",
  cond = os.getenv "PERPLEXITY_API_KEY" ~= nil,
}

local cmd_prefix = "GPT"

function M.config()
  require("gp").setup {
    api_key = os.getenv "PERPLEXITY_API_KEY",
    cmd_prefix = cmd_prefix,
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
        gp.Prompt(params, gp.Target.popup, nil, agent.model, template, agent.system_prompt)
      end,
      FixBugs = function(gp, params)
        local template = "Fix bugs in the below code from {{filename}} carefully and logically:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Fixed code:\n"
        local agent = gp.get_command_agent()
        gp.Prompt(params, gp.Target.popup, nil, agent.model, template, agent.system_prompt)
      end,
      Optimize = function(gp, params)
        local template = "Optimize the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Optimized code:\n"
        local agent = gp.get_command_agent()
        gp.Prompt(params, gp.Target.popup, nil, agent.model, template, agent.system_prompt)
      end,
      UnitTests = function(gp, params)
        local template = "I have the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Please respond by writing table driven unit tests for the code above."
        local agent = gp.get_command_agent()
        gp.Prompt(params, gp.Target.enew, nil, agent.model, template, agent.system_prompt)
      end,
      ProofReader = function(gp, params)
        local chat_system_prompt = "I want you to act as a proofreader. I will"
          .. "provide you with texts and I would like you to review them for any"
          .. "spelling, grammar, or punctuation errors. Once you have finished"
          .. "reviewing the text, provide me with any necessary corrections or"
          .. "suggestions to improve the text. Highlight the corrections with"
          .. "markdown bold or italics style."
        local agent = gp.get_chat_agent()
        gp.cmd.ChatNew(params, agent.model, chat_system_prompt)
      end,
      Debug = function(gp, params)
        local template = "I want you to act as {{filetype}} expert.\n"
          .. "Review the following code, carefully examine it and report"
          .. "potential bugs and edge cases alongside solutions to resolve them."
          .. "Keep your explanation short and to the point:"
          .. "```{{filetype}}{{selection}}\n```\n\n"
        local agent = gp.get_chat_agent()
        gp.Prompt(params, gp.Target.enew, nil, agent.model, template, agent.system_prompt)
      end,
    },
  }
  local unused_commands = {
    "Whisper",
    "WhisperRewrite",
    "WhisperAppend",
    "WhisperPrepend",
    "WhisperEnew",
    "WhisperNew",
    "WhisperVnew",
    "WhisperTabnew",
    "WhisperPopup",
    "Image",
    "ImageAgent",
  }
  for _, command in ipairs(unused_commands) do
    vim.api.nvim_del_user_command(cmd_prefix .. command)
  end
end

function M.keys()
  local function kmopts(desc)
    return {
      noremap = true,
      silent = true,
      nowait = true,
      desc = desc,
    }
  end
  return {
    {
      "<C-g>c",
      "<cmd>" .. cmd_prefix .. "ChatNew<cr>",
      mode = { "n", "i" },
      kmopts "New Chat",
    },
    {
      "<C-g>t",
      "<cmd>" .. cmd_prefix .. "ChatToggle tabnew<cr>",
      mode = { "n", "i" },
      kmopts "Toggle Popup Chat",
    },
    {
      "<C-g>f",
      "<cmd>" .. cmd_prefix .. "ChatFinder<cr>",
      mode = { "n", "i" },
      kmopts "Chat Finder",
    },
    {
      "<C-g>r",
      "<cmd>" .. cmd_prefix .. "Rewrite<cr>",
      mode = { "n", "i" },
      kmopts "Inline Rewrite",
    },
    {
      "<C-g>a",
      "<cmd>" .. cmd_prefix .. "Append<cr>",
      mode = { "n", "i" },
      kmopts "Append",
    },
    {
      "<C-g>o",
      "<cmd>" .. cmd_prefix .. "Prepend<cr>",
      mode = { "n", "i" },
      kmopts "Prepend",
    },
    {
      "<C-g>e",
      "<cmd>" .. cmd_prefix .. "Enew<cr>",
      mode = { "n", "i" },
      kmopts "Enew",
    },
    {
      "<C-g>p",
      "<cmd>" .. cmd_prefix .. "Popup<cr>",
      mode = { "n", "i" },
      kmopts "Popup",
    },
    {
      "<C-g>c",
      ":<C-u>'<,'>" .. cmd_prefix .. "ChatNew<cr>",
      mode = { "v" },
      kmopts "Visual Chat New",
    },
    {
      "<C-g>t",
      ":<C-u>'<,'>" .. cmd_prefix .. "ChatToggle tabnew<cr>",
      mode = { "v" },
      kmopts "Visual Popup Chat",
    },
    {
      "<C-g>r",
      ":<C-u>'<,'>" .. cmd_prefix .. "Rewrite<cr>",
      mode = { "v" },
      kmopts "Visual Rewrite",
    },
    {
      "<C-g>a",
      ":<C-u>'<,'>" .. cmd_prefix .. "Append<cr>",
      mode = { "v" },
      kmopts "Visual Append",
    },
    {
      "<C-g>o",
      ":<C-u>'<,'>" .. cmd_prefix .. "Prepend<cr>",
      mode = { "v" },
      kmopts "Visual Prepend",
    },
    {
      "<C-g>e",
      ":<C-u>'<,'>" .. cmd_prefix .. "Enew<cr>",
      mode = { "v" },
      kmopts "Visual Enew",
    },
    {
      "<C-g>p",
      ":<C-u>'<,'>" .. cmd_prefix .. "Popup<cr>",
      mode = { "v" },
      kmopts "Visual Popup",
    },
    {
      "<C-g>s",
      "<cmd>" .. cmd_prefix .. "Stop<cr>",
      mode = { "n", "i", "v", "x" },
      kmopts "Stop",
    },
    {
      "<C-g>i",
      ":<C-u>'<,'>" .. cmd_prefix .. "Complete<cr>",
      mode = { "n", "i", "v", "x" },
      kmopts "Complete the visual selection",
    },
    {
      "<C-g>n",
      "<cmd>" .. cmd_prefix .. "NextAgent<cr>",
      mode = { "n" },
      kmopts "Cycle through available agents",
    },
    {
      "<C-g>x",
      "<cmd>" .. cmd_prefix .. "Context<cr>",
      mode = { "n" },
      kmopts "Open file with custom context",
    },
  }
end

return M
