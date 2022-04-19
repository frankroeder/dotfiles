-- nvim-cmp setup
local cmp = require 'cmp'
local cmp_autopairs = require('nvim-autopairs.completion.cmp')

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menu,menuone,noselect'
-- vim.o.pumheight = 35

-- https://github.com/hrsh7th/nvim-cmp/issues/602
vim.g.copilot_no_tab_map = true
vim.g.copilot_assume_mapped = true

vim.g.copilot_tab_fallback = ""
vim.g.copilot_filetypes = {
	["*"] = false,
	python = true,
	lua = true,
}

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
    ['<Tab>'] = cmp.mapping.select_next_item(),
    ['<S-Tab>'] = cmp.mapping.select_prev_item(),
    -- Accept currently selected item. If none selected, `select` first item.
    -- Set `select` to `false` to only confirm explicitly selected items.
    ['<CR>'] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Insert,
      select = false,
    }),
    ['<C-Y>'] = cmp.mapping(function(fallback)
      vim.api.nvim_feedkeys(vim.fn['copilot#Accept'](vim.api.nvim_replace_termcodes('<Tab>', true, true, true)), 'n', true)
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
