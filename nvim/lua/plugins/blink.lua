return {
  "saghen/blink.cmp",
  build = "cargo build --release",
  dependencies = {
    { "L3MON4D3/LuaSnip", version = "v2.*" },
    "archie-judd/blink-cmp-words",
  },
  opts = {
    keymap = {
      preset = "enter",
      ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      ["<Up>"] = {},
      ["<Down>"] = {},
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
      menu = {
        auto_show = true,
        draw = {
          treesitter = { "lsp" },
        },
      },

      documentation = {
        auto_show = true,
        auto_show_delay_ms = 150,
      },
      ghost_text = { enabled = false },
    },

    signature = {
      enabled = true,
    },

    fuzzy = { implementation = "prefer_rust_with_warning" },

    sources = {
      default = function()
        local success, node = pcall(vim.treesitter.get_node)
        if
          success
          and node
          and vim.tbl_contains({ "comment", "line_comment", "block_comment" }, node:type())
        then
          return { "buffer" }
        elseif vim.bo.filetype == "tex" or vim.bo.filetype == "bib" then
          return { "buffer", "omni", "snippets", "thesaurus" }
        elseif
          node and vim.tbl_contains({ "comment", "line_comment", "block_comment" }, node:type())
        then
          return { "buffer" }
        else
          local prov = { "lsp", "snippets", "path", "buffer", "parrot" }
          if vim.bo.filetype == "lua" then
            table.insert(prov, "lazydev")
          end
          if vim.bo.filetype == "markdown" then
            table.insert(prov, "markdown")
            table.insert(prov, "thesaurus")
          end
          return prov
        end
      end,

      providers = {
        path = {
          opts = {
            show_hidden_files_by_default = true,
          },
        },
        buffer = {
          min_keyword_length = 2,
          max_items = 5,
        },
        lsp = {
          min_keyword_length = 2,
          fallbacks = { "lazydev" },
        },
        markdown = {
          name = "RenderMarkdown",
          module = "render-markdown.integ.blink",
          fallbacks = { "lsp" },
        },
        lazydev = {
          name = "LazyDev",
          module = "lazydev.integrations.blink",
          score_offset = 100,
        },
        parrot = {
          module = "parrot.completion.blink",
          name = "parrot",
          score_offset = 20,
          transform_items = function(ctx, items)
            for _, item in ipairs(items) do
              item.kind_icon = "🦜"
              item.kind_name = "parrot"
            end
            return items
          end,
        },
        -- Use the thesaurus source
        thesaurus = {
          name = "blink-cmp-words",
          module = "blink-cmp-words.thesaurus",
          opts = {
            score_offset = 0,
            pointer_symbols = { "!", "&", "^" },
          },
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
}
