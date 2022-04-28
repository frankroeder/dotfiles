-- nvim-cmp setup
local cmp = require 'cmp'
local cmp_autopairs = require('nvim-autopairs.completion.cmp')

-- vim.o.pumheight = 35

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
  Variable = ""
}
local cmp_ultisnips_mappings = require("cmp_nvim_ultisnips.mappings")

cmp.setup {
  snippet = {
    expand = function(args)
      vim.fn["UltiSnips#Anon"](args.body)
    end,
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'path' },
    { name = 'ultisnips', max_item_count = 5 },
    { name = 'buffer', max_item_count = 5, keyword_length = 3 },
    { name = 'treesitter', max_item_count = 5, keyword_length = 3 },
    { name = 'copilot' },
  },
  formatting = {
    format = function(entry, vim_item)
      vim_item.kind = string.format('%s %s', kind_icons[vim_item.kind], vim_item.kind)
      vim_item.menu = ({
        nvim_lsp = "[LSP]",
        path = "[Path]",
        ultisnips = "[USnips]",
        buffer = "[Buffer]",
        nvim_lua = "[Lua]",
        treesitter = "[Treesitter]",
        copilot = "[Copilot]",
      })[entry.source.name]
      return vim_item
    end
  },
  mapping = {
    ['<C-Space>'] = cmp.mapping(cmp.mapping.complete()),
    ['<C-d>'] = cmp.mapping(cmp.mapping.scroll_docs(-4)),
    ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4)),
    ['<C-e>'] = cmp.mapping({
      i = cmp.mapping.abort(),
      c = cmp.mapping.close(),
    }),

    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      else
        fallback() -- The fallback function sends a already mapped key. In this case, it's probably `<Tab>`.
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      else
        fallback()
      end
    end, { "i", "s" }),
    -- Accept currently selected item. If none selected, `select` first item.
    -- Set `select` to `false` to only confirm explicitly selected items.
    ['<CR>'] = cmp.mapping.confirm({ select = false }),
  }
}
-- fix jumping through snippet stops
vim.g.UltiSnipsRemoveSelectModeMappings = 0

vim.api.nvim_create_autocmd({"VimEnter"}, {
  pattern = {"*.py", "*.lua"},
  callback = function() require("copilot").setup({ plugin_manager_path = vim.g.plug_dir }) end,
})

require('nvim-autopairs').setup({
  disable_filetype = { "vim", "help" },
})
cmp.event:on('confirm_done',
  cmp_autopairs.on_confirm_done({
    map_char = { tex = '' }
  })
)
