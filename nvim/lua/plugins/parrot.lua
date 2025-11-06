local utils = require "utils"
local Job = require "plenary.job"

local _anthropic = {
  name = "anthropic",
  endpoint = "https://api.anthropic.com/v1/messages",
  model_endpoint = "https://api.anthropic.com/v1/models",
  api_key = utils.get_api_key("anthropic-api-key", "ANTHROPIC_API_KEY"),
  params = {
    chat = { max_tokens = 4096 },
    command = { max_tokens = 4096 },
  },
  topic = {
    model = "claude-3-5-haiku-latest",
    params = { max_tokens = 32 },
  },
  headers = function(self)
    return {
      ["Content-Type"] = "application/json",
      ["x-api-key"] = self.api_key,
      ["anthropic-version"] = "2023-06-01",
    }
  end,
  -- Using model aliases (https://docs.anthropic.com/en/docs/about-claude/models/overview#model-aliases)
  models = {
    "claude-opus-4-1",
    "claude-opus-4-0",
    "claude-sonnet-4-0",
    "claude-3-7-sonnet-latest",
    "claude-3-5-sonnet-latest",
    "claude-3-5-haiku-latest",
  },
  preprocess_payload = function(payload)
    for _, message in ipairs(payload.messages) do
      message.content = message.content:gsub("^%s*(.-)%s*$", "%1")
    end
    if payload.messages[1] and payload.messages[1].role == "system" then
      -- remove the first message that serves as the system prompt as anthropic
      -- expects the system prompt to be part of the API call body and not the messages
      payload.system = payload.messages[1].content
      table.remove(payload.messages, 1)
    end
    return payload
  end,
}

local M = {
  "frankroeder/parrot.nvim",
  event = "VeryLazy",
  dependencies = { "ibhagwan/fzf-lua", "nvim-lua/plenary.nvim" },
  dev = vim.fn.has "macunix" == 1 and vim.fn.expand "$USER" == "frankroeder",
  lazy = false,
  config = function(_, opts)
    -- add ollama if executable found
    if vim.fn.executable "ollama" == 1 then
      opts.providers["ollama"] = {
        name = "ollama",
        endpoint = "http://localhost:11434/api/chat",
        model_endpoint = "http://localhost:11434/api/models",
        api_key = "", -- not required for local Ollama
        params = {
          chat = { temperature = 1.5, top_p = 1, num_ctx = 8192, min_p = 0.05 },
          command = { temperature = 1.5, top_p = 1, num_ctx = 8192, min_p = 0.05 },
        },
        topic_prompt = [[
        Summarize the chat above and only provide a short headline of 2 to 3
        words without any opening phrase like "Sure, here is the summary",
        "Sure! Here's a shortheadline summarizing the chat" or anything similar.
        ]],
        topic = {
          model = "llama3.2",
          params = { max_tokens = 32 },
        },
        headers = {
          ["Content-Type"] = "application/json",
        },
        models = {
          "codestral",
          "llama3.2",
          "gemma3",
        },
        resolve_api_key = function()
          return true
        end,
        process_stdout = function(response)
          if response:match "message" and response:match "content" then
            local ok, data = pcall(vim.json.decode, response)
            if ok and data.message and data.message.content then
              return data.message.content
            end
          end
        end,
        get_available_models = function(self)
          local url = self.endpoint:gsub("chat", "")
          local logger = require "parrot.logger"
          local job = Job:new({
            command = "curl",
            args = { "-H", "Content-Type: application/json", url .. "tags" },
          }):sync()
          local parsed_response = require("parrot.utils").parse_raw_response(job)
          self:process_onexit(parsed_response)
          if parsed_response == "" then
            logger.debug("Ollama server not running on " .. endpoint_api)
            return {}
          end

          local success, parsed_data = pcall(vim.json.decode, parsed_response)
          if not success then
            logger.error("Ollama - Error parsing JSON: " .. vim.inspect(parsed_data))
            return {}
          end

          if not parsed_data.models then
            logger.error "Ollama - No models found. Please use 'ollama pull' to download one."
            return {}
          end

          local names = {}
          for _, model in ipairs(parsed_data.models) do
            table.insert(names, model.name)
          end

          return names
        end,
      }
    end
    require("parrot").setup(opts)
  end,
  opts = {
    providers = {
      xai = {
        name = "xai",
        endpoint = "https://api.x.ai/v1/chat/completions",
        model_endpoint = "https://api.x.ai/v1/language-models",
        api_key = os.getenv "XAI_API_KEY",
        params = {
          chat = { temperature = 1.1, top_p = 1 },
          command = { temperature = 1.1, top_p = 1 },
        },
        topic = {
          model = "grok-3-mini",
          params = { max_completion_tokens = 64 },
        },
        models = {
          "grok-3",
          "grok-3-mini",
          "grok-4-0709",
        },
      },
      openai = {
        name = "openai",
        endpoint = "https://api.openai.com/v1/chat/completions",
        model_endpoint = "https://api.openai.com/v1/models",
        api_key = utils.get_api_key("openai-api-key", "OPENAI_API_KEY"),
        params = {
          chat = {
            temperature = 1.1,
            top_p = 1,
            stream_options = { include_usage = true },
          },
          command = {
            temperature = 1.1,
            top_p = 1,
            stream_options = { include_usage = true },
          },
        },
        topic = {
          model = "gpt-5-nano",
          params = { max_completion_tokens = 64 },
        },
        models = {
          "gpt-5",
          "gpt-5-nano",
          "gpt-5-mini",
          "gpt-5-chat-latest",
        },
      },
      anthropic = _anthropic,
      -- use models with web search
      anthropic_web = vim.tbl_extend("force", _anthropic, {
        name = "anthropic_web",
        params = {
          chat = {
            max_tokens = 4096,
            tools = {
              {
                ["type"] = "web_search_20250305",
                ["name"] = "web_search",
                ["max_uses"] = 5,
              },
            },
          },
          command = {
            max_tokens = 4096,
            tools = {
              {
                ["type"] = "web_search_20250305",
                ["name"] = "web_search",
                ["max_uses"] = 5,
              },
            },
          },
        },
      }),
      -- use models with hard-coded thinking parameters
      anthropic_thinking = vim.tbl_extend("force", _anthropic, {
        name = "anthropic_thinking",
        params = {
          chat = {
            max_tokens = 4096,
            thinking = {
              type = "enabled",
              budget_tokens = 2048,
            },
          },
          command = {
            max_tokens = 4096,
            thinking = {
              type = "enabled",
              budget_tokens = 2048,
            },
          },
        },
        models = {
          "claude-opus-4-0",
          "claude-sonnet-4-0",
          "claude-3-7-sonnet-latest",
        },
      }),
      gemini = {
        name = "gemini",
        endpoint = function(self)
          return "https://generativelanguage.googleapis.com/v1beta/models/"
            .. self._model
            .. ":streamGenerateContent?alt=sse"
        end,
        model_endpoint = function(self)
          return { "https://generativelanguage.googleapis.com/v1beta/models?key=" .. self.api_key }
        end,
        api_key = os.getenv "GEMINI_API_KEY",
        params = {
          chat = { temperature = 1.1, topP = 1, topK = 10, maxOutputTokens = 8192 },
          command = { temperature = 0.8, topP = 1, topK = 10, maxOutputTokens = 8192 },
        },
        topic = {
          model = "gemini-1.5-flash",
          params = { maxOutputTokens = 64 },
        },
        headers = function(self)
          return {
            ["Content-Type"] = "application/json",
            ["x-goog-api-key"] = self.api_key,
          }
        end,
        models = {
          "gemini-2.5-flash-preview-05-20",
          "gemini-2.5-pro-preview-05-06",
          "gemini-1.5-pro-latest",
          "gemini-1.5-flash-latest",
          "gemini-2.5-pro-exp-03-25",
          "gemini-2.0-flash-lite",
          "gemini-2.0-flash-thinking-exp",
          "gemma-3-27b-it",
        },
        preprocess_payload = function(payload)
          local contents = {}
          local system_instruction = nil
          for _, message in ipairs(payload.messages) do
            if message.role == "system" then
              system_instruction = { parts = { { text = message.content } } }
            else
              local role = message.role == "assistant" and "model" or "user"
              table.insert(
                contents,
                { role = role, parts = { { text = message.content:gsub("^%s*(.-)%s*$", "%1") } } }
              )
            end
          end
          local gemini_payload = {
            contents = contents,
            generationConfig = {
              temperature = payload.temperature,
              topP = payload.topP or payload.top_p,
              maxOutputTokens = payload.max_tokens or payload.maxOutputTokens,
            },
          }
          if system_instruction then
            gemini_payload.systemInstruction = system_instruction
          end
          return gemini_payload
        end,
        process_stdout = function(response)
          if not response or response == "" then
            return nil
          end
          local success, decoded = pcall(vim.json.decode, response)
          if
            success
            and decoded.candidates
            and decoded.candidates[1]
            and decoded.candidates[1].content
            and decoded.candidates[1].content.parts
            and decoded.candidates[1].content.parts[1]
          then
            return decoded.candidates[1].content.parts[1].text
          end
          return nil
        end,
      },
    },
    cmd_prefix = "Prt",
    chat_conceal_model_params = false,
    user_input_ui = "buffer",
    toggle_target = "",
    online_model_selection = true,
    command_auto_select_response = true,
    show_context_hints = true,
    model_cache_expiry_hours = 0,
    prompts = {
      ["git commit message"] = [[Given the following git diff, I want you to compose a short git commit message ]]
        .. vim.fn.system "git diff --no-color --no-ext-diff --staged",
    },
    hooks = {
      Complete = function(prt, params)
        local template = [[
        I have the following code from {{filename}}:

        ```{{filetype}}
        {{selection}}
        ```

        Please finish the code above carefully and logically.
        Respond just with the snippet of code that should be inserted."
        ]]
        local model_obj = prt.get_model "command"
        prt.Prompt(params, prt.ui.Target.append, model_obj, nil, template)
      end,
      CompleteFullContext = function(prt, params)
        local template = [[
        I have the following code from {{filename}}:

        ```{{filetype}}
        {{filecontent}}
        ```

        Please look at the following section specifically:
        ```{{filetype}}
        {{selection}}
        ```

        Please finish the code above carefully and logically.
        Respond just with the snippet of code that should be inserted.
        ]]
        local model_obj = prt.get_model "command"
        prt.Prompt(params, prt.ui.Target.append, model_obj, nil, template)
      end,
      CompleteMultiContext = function(prt, params)
        local template = [[
        I have the following code from {{filename}} and other realted files:

        ```{{filetype}}
        {{multifilecontent}}
        ```

        Please look at the following section specifically:
        ```{{filetype}}
        {{selection}}
        ```

        Please finish the code above carefully and logically.
        Respond just with the snippet of code that should be inserted.
        ]]
        local model_obj = prt.get_model "command"
        prt.Prompt(params, prt.ui.Target.append, model_obj, nil, template)
      end,
      Explain = function(prt, params)
        local template = [[
        Your task is to take the code snippet from {{filename}} and explain it with gradually increasing complexity.
        Break down the code's functionality, purpose, and key components.
        The goal is to help the reader understand what the code does and how it works.

        ```{{filetype}}
        {{selection}}
        ```

        Use the markdown format with codeblocks and inline code.
        Explanation of the code above:
        ]]
        local model = prt.get_model "command"
        prt.logger.info("Explaining selection with model: " .. model.name)
        prt.Prompt(params, prt.ui.Target.new, model, nil, template)
      end,
      FixBugs = function(prt, params)
        local template = [[
        You are an expert in {{filetype}}.
        Fix bugs in the below code from {{filename}} carefully and logically:
        Your task is to analyze the provided {{filetype}} code snippet, identify
        any bugs or errors present, and provide a corrected version of the code
        that resolves these issues. Explain the problems you found in the
        original code and how your fixes address them. The corrected code should
        be functional, efficient, and adhere to best practices in
        {{filetype}} programming.

        ```{{filetype}}
        {{selection}}
        ```

        Fixed code:
        ]]
        local model_obj = prt.get_model "command"
        prt.logger.info("Fixing bugs in selection with model: " .. model_obj.name)
        prt.Prompt(params, prt.ui.Target.new, model_obj, nil, template)
      end,
      Optimize = function(prt, params)
        local template = [[
        You are an expert in {{filetype}}.
        Your task is to analyze the provided {{filetype}} code snippet and
        suggest improvements to optimize its performance. Identify areas
        where the code can be made more efficient, faster, or less
        resource-intensive. Provide specific suggestions for optimization,
        along with explanations of how these changes can enhance the code's
        performance. The optimized code should maintain the same functionality
        as the original code while demonstrating improved efficiency.

        ```{{filetype}}
        {{selection}}
        ```

        Optimized code:
        ]]
        local model_obj = prt.get_model "command"
        prt.logger.info("Optimizing selection with model: " .. model_obj.name)
        prt.Prompt(params, prt.ui.Target.new, model_obj, nil, template)
      end,
      UnitTests = function(prt, params)
        local template = [[
        I have the following code from {{filename}}:

        ```{{filetype}}
        {{selection}}
        ```

        Please respond by writing table driven unit tests for the code above.
        ]]
        local model_obj = prt.get_model "command"
        prt.logger.info("Creating unit tests for selection with model: " .. model_obj.name)
        prt.Prompt(params, prt.ui.Target.enew, model_obj, nil, template)
      end,
      Debug = function(prt, params)
        local template = [[
        I want you to act as {{filetype}} expert.
        Review the following code, carefully examine it, and report potential
        bugs and edge cases alongside solutions to resolve them.
        Keep your explanation short and to the point:

        ```{{filetype}}
        {{selection}}
        ```
        ]]
        local model_obj = prt.get_model "command"
        prt.logger.info("Debugging selection with model: " .. model_obj.name)
        prt.Prompt(params, prt.ui.Target.enew, model_obj, nil, template)
      end,
      CommitMsg = function(prt, params)
        local futils = require "parrot.file_utils"
        if futils.find_git_root() == "" then
          prt.logger.warning "Not in a git repository"
          return
        else
          local template = [[
          I want you to act as a commit message generator. I will provide you
          with information about the task and the prefix for the task code, and
          I would like you to generate an appropriate commit message using the
          conventional commit format. Do not write any explanations or other
          words, just reply with the commit message.
          Start with a short headline as summary but then list the individual
          changes in more detail.

          Here are the changes that should be considered by this message:
          ]] .. vim.fn.system "git diff --no-color --no-ext-diff --staged"
          local model_obj = prt.get_model "command"
          prt.Prompt(params, prt.ui.Target.append, model_obj, nil, template)
        end
      end,
      SpellCheck = function(prt, params)
        local chat_prompt = [[
        Your task is to take the text provided and rewrite it into a clear,
        grammatically correct version while preserving the original meaning
        as closely as possible. Correct any spelling mistakes, punctuation
        errors, verb tense issues, word choice problems, and other
        grammatical mistakes.
        ]]
        prt.ChatNew(params, chat_prompt)
      end,
      CodeConsultant = function(prt, params)
        local chat_prompt = [[
          Your task is to analyze the provided {{filetype}} code and suggest
          improvements to optimize its performance. Identify areas where the
          code can be made more efficient, faster, or less resource-intensive.
          Provide specific suggestions for optimization, along with explanations
          of how these changes can enhance the code's performance. The optimized
          code should maintain the same functionality as the original code while
          demonstrating improved efficiency.

          Here is the code
          ```{{filetype}}
          {{filecontent}}
          ```
        ]]
        prt.ChatNew(params, chat_prompt)
      end,
      ProofReader = function(prt, params)
        local chat_prompt = [[
        I want you to act as a proofreader. I will provide you with texts and
        I would like you to review them for any spelling, grammar, or
        punctuation errors. Once you have finished reviewing the text,
        provide me with any necessary corrections or suggestions to improve the
        text. Highlight the corrected fragments (if any) using markdown backticks.

        When you have done that subsequently provide me with a slightly better
        version of the text, but keep close to the original text.

        Finally provide me with an ideal version of the text.

        Whenever I provide you with text, you reply in this format directly:

        ## Corrected text:

        {corrected text, or say "NO_CORRECTIONS_NEEDED" instead if there are no corrections made}

        ## Slightly better text

        {slightly better text}

        ## Ideal text

        {ideal text}
        ]]
        prt.ChatNew(params, chat_prompt)
      end,
    },
  },
  keys = {
    { "<C-g>c", "<cmd>PrtChatNew<cr>", mode = { "n", "i" }, desc = "New Chat" },
    { "<C-g>c", ":<C-u>'<,'>PrtChatNew<cr>", mode = { "v" }, desc = "Visual Chat New" },
    { "<C-g>t", "<cmd>PrtChatToggle<cr>", mode = { "n", "i" }, desc = "Toggle Popup Chat" },
    { "<C-g>f", "<cmd>PrtChatFinder<cr>", mode = { "n", "i" }, desc = "Chat Finder" },
    { "<C-g>r", "<cmd>PrtRewrite<cr>", mode = { "n", "i" }, desc = "Inline Rewrite" },
    { "<C-g>r", ":<C-u>'<,'>PrtRewrite<cr>", mode = { "v" }, desc = "Visual Rewrite" },
    {
      "<C-g>j",
      "<cmd>PrtRetry<cr>",
      mode = { "n" },
      desc = "Retry rewrite/append/prepend command",
    },
    { "<C-g>a", "<cmd>PrtAppend<cr>", mode = { "n", "i" }, desc = "Append" },
    { "<C-g>a", ":<C-u>'<,'>PrtAppend<cr>", mode = { "v" }, desc = "Visual Append" },
    { "<C-g>o", "<cmd>PrtPrepend<cr>", mode = { "n", "i" }, desc = "Prepend" },
    { "<C-g>o", ":<C-u>'<,'>PrtPrepend<cr>", mode = { "v" }, desc = "Visual Prepend" },
    { "<C-g>e", ":<C-u>'<,'>PrtEnew<cr>", mode = { "v" }, desc = "Visual Enew" },
    { "<C-g>s", "<cmd>PrtStop<cr>", mode = { "n", "i", "v", "x" }, desc = "Stop" },
    {
      "<C-g>i",
      ":<C-u>'<,'>PrtComplete<cr>",
      mode = { "n", "i", "v", "x" },
      desc = "Complete visual selection",
    },
    { "<C-g>x", "<cmd>PrtContext<cr>", mode = { "n" }, desc = "Open context file" },
    { "<C-g>n", "<cmd>PrtModel<cr>", mode = { "n" }, desc = "Select model" },
    { "<C-g>p", "<cmd>PrtProvider<cr>", mode = { "n" }, desc = "Select provider" },
    { "<C-g>q", "<cmd>PrtAsk<cr>", mode = { "n" }, desc = "Ask a question" },
  },
}

return M
