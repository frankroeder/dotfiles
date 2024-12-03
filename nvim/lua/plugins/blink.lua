return {
  "saghen/blink.cmp",
  build = "cargo build --release",
  dependencies = {
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
    "micangl/cmp-vimtex",
    { "saghen/blink.compat", opts = { impersonate_nvim_cmp = true } },
  },
  opts = {
    keymap = {
      preset = "enter",
      ["<Tab>"] = { "select_next", "fallback" },
      ["<S-Tab>"] = { "select_prev", "fallback" },
      ["<CR>"] = { "select_and_accept", "fallback" },
      ["<C-y>"] = { "select_and_accept" },
      ["<C-J>"] = { "snippet_forward", "fallback" },
      ["<C-K>"] = { "snippet_backward", "fallback" },
      ["<C-L>"] = { "select_and_accept" },
    },

    snippets = {
      -- Function to use when expanding LSP provided snippets
      expand = function(snippet)
        require("luasnip").lsp_expand(snippet)
      end,
      -- -- Function to use when checking if a snippet is active
      active = function(filter)
        if filter and filter.direction then
          return require("luasnip").jumpable(filter.direction)
        end
        return require("luasnip").in_snippet()
      end,
      -- Function to use when jumping between tab stops in a snippet, where direction can be negative or positive
      jump = function(direction)
        require("luasnip").jump(direction)
      end,
    },

    completion = {
      keyword = {
        range = "full",
      },
      trigger = {
        -- When false, will not show the completion window automatically when in a snippet
        show_in_snippet = true,
        -- When true, will show the completion window after typing a character that matches the `keyword.regex`
        show_on_keyword = true,
        -- When true, will show the completion window after typing a trigger character
        show_on_trigger_character = true,
        -- LSPs can indicate when to show the completion window via trigger characters
        -- however, some LSPs (i.e. tsserver) return characters that would essentially
        -- always show the window. We block these by default.
        show_on_blocked_trigger_characters = { " ", "\n", "\t" },
        -- When both this and show_on_trigger_character are true, will show the completion window
        -- when the cursor comes after a trigger character after accepting an item
        show_on_accept_on_trigger_character = true,
        -- When both this and show_on_trigger_character are true, will show the completion window
        -- when the cursor comes after a trigger character when entering insert mode
        show_on_insert_on_trigger_character = true,
        -- List of trigger characters (on top of `show_on_blocked_trigger_characters`) that won't trigger
        -- the completion window when the cursor comes after a trigger character when
        -- entering insert mode/accepting an item
        show_on_x_blocked_trigger_characters = { "'", '"', "(" },
      },
      list = {
        -- Maximum number of items to display
        max_items = 100,
        selection = "auto_insert",
      },
      accept = {
        auto_brackets = {
          -- Whether to auto-insert brackets for functions
          enabled = true,
        },
      },
      menu = {
        border = "rounded",
        draw = {
          columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
        },
      },

      documentation = {
        -- Controls whether the documentation window will automatically show when selecting a completion item
        auto_show = true,
        window = {
          border = "rounded",
        },
      },
    },

    signature = {
      enabled = true,
      window = {
        border = "rounded",
      },
    },

    fuzzy = {
      -- when enabled, allows for a number of typos relative to the length of the query
      -- disabling this matches the behavior of fzf
      use_typo_resistance = false,
      max_items = 100,
    },

    sources = {
      completion = {
        enabled_providers = function(ctx)
          if vim.bo.filetype == "tex" then
            return { "buffer", "vimtex", "luasnip" }
          else
            return { "lsp", "luasnip", "path", "buffer", "lazydev" }
          end
        end,
      },
      providers = {
        vimtex = {
          name = "vimtex",
          module = "blink.compat.source",
          score_offset = -3,
          opts = {},
        },
        luasnip = {
          name = "luasnip",
          module = "blink.compat.source",

          score_offset = -3,

          opts = {
            use_show_condition = false,
            show_autosnippets = true,
          },
        },
        lsp = {
          min_keyword_length = 2,
          fallback_for = { "lazydev" },
        },
        lazydev = {
          name = "LazyDev",
          module = "lazydev.integrations.blink",
        },
      },
    },
  },

  apperance = {
    kind_icon = {
      Boolean = "",
      Class = "󰠱",
      Color = "󰏘",
      Constant = "󰏿",
      Constructor = "",
      Enum = "",
      EnumMember = "",
      Event = "",
      Field = "󰜢",
      File = "󰈙",
      Folder = "󰉋",
      Function = "󰡱",
      Interface = "",
      Keyword = "󰌋",
      Method = "󰆧",
      Module = "",
      Namespace = "",
      Operator = "󰆕",
      Property = "󰜢",
      Reference = "󰈇",
      Snippet = "",
      Struct = "󰙅",
      Text = "󰉿",
      TypeParameter = "󰬛",
      Unit = "󰑭",
      Value = "󰎠",
      Variable = "󰀫",
    },
  },
}
