return {
  "saghen/blink.cmp",
  build = "cargo build --release",
  dependencies = {
    "L3MON4D3/LuaSnip",
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

    enabled = function()
      return vim.bo.buftype ~= "prompt" and vim.bo.buftype ~= "oil" and vim.b.completion ~= false
    end,

    snippets = {
      expand = function(snippet)
        require("luasnip").lsp_expand(snippet)
      end,
      active = function(filter)
        if filter and filter.direction then
          return require("luasnip").jumpable(filter.direction)
        end
        return require("luasnip").in_snippet()
      end,
      jump = function(direction)
        require("luasnip").jump(direction)
      end,
    },

    completion = {
      keyword = {
        range = "full",
      },
      trigger = {
        show_on_insert_on_trigger_character = false,
      },
      list = {
        max_items = 100,
        selection = "auto_insert",
      },
      accept = {
        auto_brackets = {
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
        auto_show = true,
        window = {
          border = "rounded",
        },
      },
    },

    signature = {
      enabled = false,
      window = {
        border = "rounded",
      },
    },

    fuzzy = {
      use_typo_resistance = false,
    },

    sources = {
      default = function()
        local node = nil
        if not vim.bo.filetype == "oil" then
          node = vim.treesitter.get_node()
        end
        if vim.bo.filetype == "tex" then
          return { "buffer", "vimtex", "luasnip" }
        elseif
          node and vim.tbl_contains({ "comment", "line_comment", "block_comment" }, node:type())
        then
          return { "buffer" }
        else
          return { "lsp", "luasnip", "path", "buffer", "lazydev" }
        end
      end,
      cmdline = {},
      providers = {
        buffer = {
          max_items = 5,
          min_keyword_length = 3,
        },
        path = {
          opts = {
            show_hidden_files_by_default = true,
          },
        },
        vimtex = {
          name = "vimtex",
          module = "blink.compat.source",
          score_offset = -3,
          opts = {},
        },
        lsp = {
          min_keyword_length = 2,
          fallbacks = { "lazydev" },
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
