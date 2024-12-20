local M = {
  "iguanacucumber/magazine.nvim",
  name = "nvim-cmp",
  event = { "InsertEnter", "CmdlineEnter" },
  dependencies = {
    { "iguanacucumber/mag-nvim-lsp", name = "cmp-nvim-lsp", opts = {} },
    { "iguanacucumber/mag-buffer", name = "cmp-buffer" },
    "https://codeberg.org/FelipeLema/cmp-async-path",
    "hrsh7th/cmp-omni",
    { "iguanacucumber/mag-cmdline", name = "cmp-cmdline" },
    "saadparwaiz1/cmp_luasnip",
    "ray-x/cmp-treesitter",
  },
}
function M.config()
  local cmp_status_ok, cmp = pcall(require, "cmp")
  if not cmp_status_ok then
    return
  end
  local luasnip_status_ok, luasnip = pcall(require, "luasnip")
  if not luasnip_status_ok then
    return
  end
  local kind_icons = {
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
    TypeParameter = "",
    Unit = "󰑭",
    Value = "󰎠",
    Variable = "󰀫",
  }
  local source_mapping = {
    nvim_lsp = "[LSP]",
    path = "[Path]",
    buffer = "[Buffer]",
    luasnip = "[LSnip]",
    nvim_lua = "[Lua]",
    treesitter = "[Treesitter]",
  }
  local has_words_before = function()
    if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
      return false
    end
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    return col ~= 0
      and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match "^%s*$" == nil
  end
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
      { name = "nvim_lsp" },
      { name = "luasnip" },
      { name = "buffer", keyword_length = 3 },
      { name = "treesitter", keyword_length = 3 },
      { name = "async_path" },
      {
        name = "lazydev",
        -- set group index to 0 to skip loading LuaLS completions as lazydev recommends it
        group_index = 0,
      },
    },
    formatting = {
      format = function(entry, vim_item)
        vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind], vim_item.kind)
        vim_item.menu = source_mapping[entry.source.name]
        return vim_item
      end,
    },
    mapping = cmp.mapping.preset.insert {
      -- ["<C-Space>"] = cmp.mapping(cmp.mapping.complete()),
      ["<C-Space>"] = cmp.mapping(
        cmp.mapping.complete {
          reason = cmp.ContextReason.Auto,
        },
        { "i", "c" }
      ),
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
  cmp.setup.cmdline(":", {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
      { name = "path" },
    }, {
      { name = "cmdline" },
    }),
  })
end
return M
