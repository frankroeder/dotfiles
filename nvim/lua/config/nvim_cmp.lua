-- nvim-cmp setup
local cmp = require 'cmp'
local cmp_autopairs = require('nvim-autopairs.completion.cmp')

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menu,menuone,noselect'
-- vim.o.pumheight = 35

-- https://github.com/hrsh7th/nvim-cmp/issues/602
vim.g.copilot_no_tab_map = true
vim.g.copilot_assume_mapped = true

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
    { name = "copilot" },
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
        latex_symbols = "[Latex]", -- FIXME
        copilot = "[Copilot]",
      })[entry.source.name]
      return vim_item
    end
  },
  mapping = {
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-n>'] = cmp.mapping.select_next_item(),
    ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
    ['<C-d>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
    ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
    ['<C-e>'] = cmp.mapping({
      i = cmp.mapping.abort(),
      c = cmp.mapping.close(),
    }),
    -- Accept currently selected item. If none selected, `select` first item.
    -- Set `select` to `false` to only confirm explicitly selected items.
    ['<CR>'] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Insert,
      select = false,
    }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      cmp_ultisnips_mappings.expand_or_jump_forwards(fallback)
    end, { "i", "s", }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      cmp_ultisnips_mappings.jump_backwards(fallback)
    end, { "i", "s", })
  }
}
-- fix jumping through snippet stops
vim.g.UltiSnipsRemoveSelectModeMappings = 0

require('nvim-autopairs').setup({
  disable_filetype = { "vim", "help" },
})
cmp.event:on('confirm_done',
  cmp_autopairs.on_confirm_done({
    map_char = { tex = '' }
  })
)
