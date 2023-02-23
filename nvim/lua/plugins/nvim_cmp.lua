local M = {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-nvim-lua",
    "hrsh7th/cmp-omni",
    "saadparwaiz1/cmp_luasnip",
    "ray-x/cmp-treesitter",
    "windwp/nvim-autopairs",
  },
}

function M.config()
  local cmp_status_ok, cmp = pcall(require, "cmp")
  if not cmp_status_ok then
    return
  end

  local status_ok, luasnip = pcall(require, "luasnip")
  if not status_ok then
    return
  end

  local kind_icons = {
    Boolean = "",
    Class = "ﴯ",
    Color = "",
    Constant = "",
    Constructor = "",
    Enum = "",
    EnumMember = "",
    Event = "",
    Field = "",
    File = "",
    Folder = "",
    Function = "",
    Interface = "",
    Keyword = "",
    Method = "",
    Module = "",
    Operator = "",
    Property = "ﰠ",
    Reference = "",
    Snippet = "",
    Struct = "ﯟ",
    Text = "",
    TypeParameter = "",
    Unit = "塞",
    Value = "",
    Variable = "",
  }

  local has_words_before = function()
    if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
      return false
    end
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    return col ~= 0
      and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match "^%s*$" == nil
  end

  vim.opt.completeopt = { "menu", "menuone", "noselect" }

  cmp.setup {
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
    sources = cmp.config.sources {
      { name = "nvim_lsp", max_item_count = 10 },
      { name = "luasnip" },
      { name = "buffer", max_item_count = 5, keyword_length = 3 },
      { name = "treesitter", max_item_count = 5, keyword_length = 3 },
      { name = "path", max_item_count = 5 },
    },
    formatting = {
      format = function(entry, vim_item)
        vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind], vim_item.kind)
        vim_item.menu = ({
          nvim_lsp = "[LSP]",
          path = "[Path]",
          buffer = "[Buffer]",
          luasnip = "[LSnip]",
          nvim_lua = "[Lua]",
          treesitter = "[Treesitter]",
        })[entry.source.name]
        return vim_item
      end,
    },
    mapping = cmp.mapping.preset.insert {
      ["<C-Space>"] = cmp.mapping(cmp.mapping.complete()),
      ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(-4)),
      ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(4)),
      ["<C-e>"] = cmp.mapping {
        i = cmp.mapping.abort(),
        c = cmp.mapping.close(),
      },

      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() and has_words_before() then
          cmp.select_next_item()
        elseif luasnip.choice_active() then
          luasnip.change_choice(1)
        else
          fallback() -- The fallback function sends a already mapped key. In this case, it's probably `<Tab>`.
        end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.choice_active() then
          luasnip.change_choice(-1)
        else
          fallback()
        end
      end, { "i", "s" }),
      -- Accept currently selected item. If none selected, `select` first item.
      -- Set `select` to `false` to only confirm explicitly selected items.
      ["<CR>"] = cmp.mapping.confirm {
        behavior = cmp.ConfirmBehavior.Replace,
        select = false,
      },
    },
  }

  -- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline({ "/", "?" }, {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
      { name = "buffer" },
    },
  })

  -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
  -- cmp.setup.cmdline(":", {
  --   mapping = cmp.mapping.preset.cmdline(),
  --   sources = cmp.config.sources({
  --     { name = "path" },
  --   }, {
  --     { name = "cmdline" },
  --   }),
  -- })

  local npairs_status_ok, npairs = pcall(require, "nvim-autopairs")
  if not npairs_status_ok then
    return
  end

  npairs.setup {
    disable_filetype = { "vim", "help" },
    check_ts = true,
    ts_config = {
      lua = { "string", "comment" }, -- it will not add a pair on that treesitter node
    },
  }

  local cmp_autopair_status_ok, cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")
  if not cmp_autopair_status_ok then
    return
  end

  cmp.event:on(
    "confirm_done",
    cmp_autopairs.on_confirm_done {
      map_char = { tex = "" },
    }
  )
end

return M
