return {
  "saghen/blink.cmp",
  build = "cargo build --release",
  dependencies = {
    "L3MON4D3/LuaSnip",
    dependencies = { "L3MON4D3/LuaSnip", version = "v2.*" },
    "micangl/cmp-vimtex",
    { "saghen/blink.compat", opts = { impersonate_nvim_cmp = true } },
  },
  opts = {
    keymap = {
      preset = "enter",
      ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      ["<CR>"] = { "select_and_accept", "fallback" },
      ["<C-L>"] = { "select_and_accept" },
    },

    enabled = function()
      return vim.bo.buftype ~= "prompt" and vim.bo.buftype ~= "oil" and vim.b.completion ~= false
    end,

    snippets = {
      preset = "luasnip",
      jump = function(direction)
        require("luasnip").change_choice(direction)
      end,
    },

    completion = {
      keyword = {
        range = "full",
      },
      list = {
        max_items = 100,
        selection = {
          preselect = false,
        },
      },
      accept = {
        auto_brackets = {
          enabled = true,
        },
      },

      -- trigger = {
      --   show_on_insert_on_trigger_character = false,
      -- },
      menu = {
        auto_show = true,
        draw = {
          treesitter = { "lsp" },
          columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
        },
      },

      documentation = {
        auto_show = true,
        auto_show_delay_ms = 150,
      },
      ghost_text = { enabled = false },
    },

    signature = {
      enabled = false,
      trigger = {
        enabled = true,
        show_on_keyword = true,
        show_on_insert = true,
      },
    },

    fuzzy = { implementation = "prefer_rust_with_warning" },

    sources = {
      default = function()
        local node = nil
        if not vim.bo.filetype == "oil" then
          node = vim.treesitter.get_node()
        end
        if vim.bo.filetype == "tex" or vim.bo.filetype == "bib" then
          return { "buffer", "vimtex", "snippets" }
        elseif
          node and vim.tbl_contains({ "comment", "line_comment", "block_comment" }, node:type())
        then
          return { "buffer" }
        else
          return { "lsp", "snippets", "path", "buffer", "lazydev" }
        end
      end,

      providers = {
        path = {
          opts = {
            show_hidden_files_by_default = true,
          },
        },
        -- buffer = {
        --   min_keyword_length = 0,
        --   max_items = 5,
        -- },
        vimtex = {
          name = "vimtex",
          module = "blink.compat.source",
          score_offset = 100,
          opts = {},
        },
        lsp = {
          min_keyword_length = 2,
          fallbacks = { "lazydev" },
        },
        lazydev = {
          name = "LazyDev",
          module = "lazydev.integrations.blink",
          score_offset = 100,
        },
      },
    },
  },

  apperance = {
    use_nvim_cmp_as_default = true,
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
      TypeParameter = "󰬛",
      Unit = "󰑭",
      Value = "󰎠",
      Variable = "󰀫",
    },
  },

  cmdline = {
    enabled = true,
    completion = {
      menu = { auto_show = true },
    },
  },
  opts_extend = { "sources.default" },
}
