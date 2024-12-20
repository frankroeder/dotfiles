return {
  "windwp/nvim-autopairs",
  event = { "InsertEnter" },
  dependencies = {
    "hrsh7th/nvim-cmp",
  },
  config = function()
    local npairs = require "nvim-autopairs"
    npairs.setup {
      disable_filetype = { "vim", "help" },
      check_ts = true,
      disable_in_macro = true,
      disable_in_replace_mode = true,
      ts_config = {
        lua = { "string", "comment", "source" }, -- it will not add a pair on that treesitter node
        javascript = { "string", "template_string" },
      },
    }
    local Rule = require "nvim-autopairs.rule"
    local cond = require "nvim-autopairs.conds"
    -- npairs.add_rules {
    --   Rule("$", "$", { "tex", "latex" })
    --     -- don't add a pair if the next character is %
    --     :with_pair(cond.not_after_regex "%%")
    --     -- don't move right when repeat character
    --     :with_move(cond.none())
    --     -- disable adding a newline when you press <cr>
    --     :with_cr(cond.none()),
    -- }
    --
    -- npairs.add_rules {
    --   Rule("$$", "$$", "tex"):with_pair(function(_opts)
    --     if _opts.line == "aa $$" then
    --       -- don't add pair on that line
    --       return false
    --     end
    --   end),
    -- }
    -- npairs.get_rules("`")[1].not_filetypes = { "tex", "latex" }
    -- npairs.get_rules("'")[1].not_filetypes = { "tex", "latex" }
    npairs.add_rules {
      Rule("`", "'", "tex"),
      Rule("$", "$", "tex"),
      Rule(" ", " ")
        :with_pair(function(opts)
          local pair = opts.line:sub(opts.col, opts.col + 1)
          return vim.tbl_contains({ "$$", "()", "{}", "[]", "<>" }, pair)
        end)
        :with_move(cond.none())
        :with_cr(cond.none())
        :with_del(function(opts)
          local col = vim.api.nvim_win_get_cursor(0)[2]
          local context = opts.line:sub(col - 1, col + 2)
          return vim.tbl_contains({ "$  $", "(  )", "{  }", "[  ]", "<  >" }, context)
        end),
      Rule("$ ", " ", "tex"):with_pair(cond.not_after_regex " "):with_del(cond.none()),
      Rule("[ ", " ", "tex"):with_pair(cond.not_after_regex " "):with_del(cond.none()),
      Rule("{ ", " ", "tex"):with_pair(cond.not_after_regex " "):with_del(cond.none()),
      Rule("( ", " ", "tex"):with_pair(cond.not_after_regex " "):with_del(cond.none()),
      Rule("< ", " ", "tex"):with_pair(cond.not_after_regex " "):with_del(cond.none()),
    }
    npairs.get_rule("$"):with_move(function(opts)
      return opts.char == opts.next_char:sub(1, 1)
    end)
    local cmp = require "cmp"
    local cmp_autopairs = require "nvim-autopairs.completion.cmp"
    cmp.event:on(
      "confirm_done",
      cmp_autopairs.on_confirm_done {
        filetypes = {
          tex = false,
        },
      }
    )
  end,
}
