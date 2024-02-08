local M = {
  "frankroeder/pplx.nvim",
  -- dir = os.getenv "HOME" .. "/Documents/luapos/pplx.nvim",
  event = "VeryLazy",
  cond = os.getenv "OPENAI_API_KEY" ~= nil or os.getenv "PERPLEXITY_API_KEY" ~= nil,
}

local cmd_prefix = "Pplx"

function M.config()
  require("pplx").setup {
    providers = {
      pplx = {
        api_key = { "/usr/bin/security", "find-generic-password", "-s perplexity-api-key", "-w" },
      },
      openai = {
        api_key = { "/usr/bin/security", "find-generic-password", "-s openai-api-key", "-w" },
      },
    },
    cmd_prefix = cmd_prefix,
    chat_conceal_model_params = false,
    hooks = {
      Complete = function(pplx, params)
        local template = "I have the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Please finish the code above carefully and logically."
          .. "\n\nRespond just with the snippet of code that should be inserted."

        local agent = pplx.get_command_agent()
        pplx.Prompt(params, pplx.Target.append, nil, agent.model, template, agent.system_prompt, agent.provider)
      end,
      Explain = function(pplx, params)
        local template = "Explain the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Use the markdown format with codeblocks.\n"
          .. "A brief explanation of what the code above is doing:\n"
        local agent = pplx.get_chat_agent()
        pplx.logger.info("Explaining selection with agent: " .. agent.name)
        pplx.Prompt(params, pplx.Target.popup, nil, agent.model, template, agent.system_prompt, agent.provider)
      end,
      FixBugs = function(pplx, params)
        local template = "You are an expert in {{filetype}}.\n"
          .. "Fix bugs in the below code from {{filename}} carefully and logically:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Fixed code:\n"
        local agent = pplx.get_command_agent()
        pplx.logger.info("Fixing bugs in selection with agent: " .. agent.name)
        pplx.Prompt(params, pplx.Target.popup, nil, agent.model, template, agent.system_prompt, agent.provider)
      end,
      Optimize = function(pplx, params)
        local template = "You are an expert in {{filetype}}.\n"
          .. "Optimize the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Optimized code:\n"
        local agent = pplx.get_command_agent()
        pplx.logger.info("Optimizing selection with agent: " .. agent.name)
        pplx.Prompt(params, pplx.Target.popup, nil, agent.model, template, agent.system_prompt, agent.provider)
      end,
      UnitTests = function(pplx, params)
        local template = "I have the following code from {{filename}}:\n\n"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
          .. "Please respond by writing table driven unit tests for the code above."
        local agent = pplx.get_command_agent()
        pplx.logger.info("Creating unit tests for selection with agent: " .. agent.name)
        pplx.Prompt(params, pplx.Target.enew, nil, agent.model, template, agent.system_prompt, agent.provider)
      end,
      ProofReader = function(pplx, params)
        local chat_system_prompt = "I want you to act as a proofreader. I will"
          .. "provide you with texts and I would like you to review them for any"
          .. "spelling, grammar, or punctuation errors. Once you have finished"
          .. "reviewing the text, provide me with any necessary corrections or"
          .. "suggestions to improve the text. Highlight the corrections with"
          .. "markdown bold or italics style."
        local agent = pplx.get_chat_agent()
        pplx.logger.info("Proofreading selection with agent: " .. agent.name)
        pplx.cmd.ChatNew(params, agent.model, chat_system_prompt)
      end,
      Debug = function(pplx, params)
        local template = "I want you to act as {{filetype}} expert.\n"
          .. "Review the following code, carefully examine it and report"
          .. "potential bugs and edge cases alongside solutions to resolve them."
          .. "Keep your explanation short and to the point:"
          .. "```{{filetype}}\n{{selection}}\n```\n\n"
        local agent = pplx.get_chat_agent()
        pplx.logger.info("Debugging selection with agent: " .. agent.name)
        pplx.Prompt(params, pplx.Target.enew, nil, agent.model, template, agent.system_prompt, agent.provider)
      end,
    },
  }
end

function M.keys()
  local kmprfx = "<C-g>"
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
      kmprfx .. "c",
      "<cmd>" .. cmd_prefix .. "ChatNew<cr>",
      mode = { "n", "i" },
      kmopts "New Chat",
    },
    {
      kmprfx .. "t",
      "<cmd>" .. cmd_prefix .. "ChatToggle tabnew<cr>",
      mode = { "n", "i" },
      kmopts "Toggle Popup Chat",
    },
    {
      kmprfx .. "f",
      "<cmd>" .. cmd_prefix .. "ChatFinder<cr>",
      mode = { "n", "i" },
      kmopts "Chat Finder",
    },
    {
      kmprfx .. "r",
      "<cmd>" .. cmd_prefix .. "Rewrite<cr>",
      mode = { "n", "i" },
      kmopts "Inline Rewrite",
    },
    {
      kmprfx .. "a",
      "<cmd>" .. cmd_prefix .. "Append<cr>",
      mode = { "n", "i" },
      kmopts "Append",
    },
    {
      kmprfx .. "o",
      "<cmd>" .. cmd_prefix .. "Prepend<cr>",
      mode = { "n", "i" },
      kmopts "Prepend",
    },
    {
      kmprfx .. "e",
      "<cmd>" .. cmd_prefix .. "Enew<cr>",
      mode = { "n", "i" },
      kmopts "Enew",
    },
    {
      kmprfx .. "p",
      "<cmd>" .. cmd_prefix .. "Popup<cr>",
      mode = { "n", "i" },
      kmopts "Popup",
    },
    {
      kmprfx .. "c",
      ":<C-u>'<,'>" .. cmd_prefix .. "ChatNew<cr>",
      mode = { "v" },
      kmopts "Visual Chat New",
    },
    {
      kmprfx .. "t",
      ":<C-u>'<,'>" .. cmd_prefix .. "ChatToggle tabnew<cr>",
      mode = { "v" },
      kmopts "Visual Popup Chat",
    },
    {
      kmprfx .. "r",
      ":<C-u>'<,'>" .. cmd_prefix .. "Rewrite<cr>",
      mode = { "v" },
      kmopts "Visual Rewrite",
    },
    {
      kmprfx .. "a",
      ":<C-u>'<,'>" .. cmd_prefix .. "Append<cr>",
      mode = { "v" },
      kmopts "Visual Append",
    },
    {
      kmprfx .. "o",
      ":<C-u>'<,'>" .. cmd_prefix .. "Prepend<cr>",
      mode = { "v" },
      kmopts "Visual Prepend",
    },
    {
      kmprfx .. "e",
      ":<C-u>'<,'>" .. cmd_prefix .. "Enew<cr>",
      mode = { "v" },
      kmopts "Visual Enew",
    },
    {
      kmprfx .. "p",
      ":<C-u>'<,'>" .. cmd_prefix .. "Popup<cr>",
      mode = { "v" },
      kmopts "Visual Popup",
    },
    {
      kmprfx .. "s",
      "<cmd>" .. cmd_prefix .. "Stop<cr>",
      mode = { "n", "i", "v", "x" },
      kmopts "Stop",
    },
    {
      kmprfx .. "i",
      ":<C-u>'<,'>" .. cmd_prefix .. "Complete<cr>",
      mode = { "n", "i", "v", "x" },
      kmopts "Complete the visual selection",
    },
    {
      kmprfx .. "n",
      "<cmd>" .. cmd_prefix .. "NextAgent<cr>",
      mode = { "n" },
      kmopts "Cycle through available agents",
    },
    {
      kmprfx .. "x",
      "<cmd>" .. cmd_prefix .. "Context<cr>",
      mode = { "n" },
      kmopts "Open file with custom context",
    },
  }
end

return M
