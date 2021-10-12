-- nvim-cmp setup
local cmp = require 'cmp'
local lspkind = require("lspkind")

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

local has_any_words_before = function()
  if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
    return false
  end
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

local press = function(key)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), "n", true)
end

cmp.setup {
  snippet = {
    expand = function(args)
      vim.fn["UltiSnips#Anon"](args.body)
    end,
  },
  formatting = {
    format = function(entry, item)
      item.kind = lspkind.presets.default[item.kind] .. " " .. item.kind
      -- set a name for each source
      item.menu =
        ({
        nvim_lsp = "[LSP]",
        path = "[Path]",
        ultisnips = "[UltiSnips]",
        buffer = "[Buffer]",
        nvim_lua = "[Lua]",
        treesitter = "[treesitter]",
        latex_symbols = "[Latex]",
      })[entry.source.name]
      return item
    end
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'path' },
    { name = 'ultisnips', max_item_count = 5 },
    { name = 'buffer', max_item_count = 5 },
    { name = 'nvim_lua' },
    { name = 'treesitter', max_item_count = 5 },
  },
  mapping = {
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-n>'] = cmp.mapping.select_next_item(),
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-e>'] = cmp.mapping.close(),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<Tab>'] =  cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif vim.fn.complete_info()["selected"] == -1 and vim.fn["UltiSnips#CanExpandSnippet"]() == 1 then
        press("<C-R>=UltiSnips#ExpandSnippet()<CR>")
      elseif vim.fn["UltiSnips#CanJumpForwards"]() == 1 then
        press("<ESC>:call UltiSnips#JumpForwards()<CR>")
      elseif has_any_words_before() then
        press("<Tab>")
      else
        fallback()
      end
    end, { "i", "s", }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif vim.fn["UltiSnips#CanJumpBackwards"]() == 1 then
        press("<ESC>:call UltiSnips#JumpBackwards()<CR>")
      else
        fallback()
      end
    end, { "i", "s", }),
  }
}
-- fix jumping through snippet stops
vim.g.UltiSnipsRemoveSelectModeMappings = 0

require('nvim-autopairs').setup({
  disable_filetype = { "vim", "help" },
})
require("nvim-autopairs.completion.cmp").setup({
  map_cr = true, --  map <CR> on insert mode
  map_complete = true, -- it will auto insert `(` (map_char) after select function or method item
  auto_select = true, -- automatically select the first item
  insert = false, -- use insert confirm behavior instead of replace
  map_char = { -- modifies the function or method delimiter by filetypes
    all = '(',
    tex = '{'
  }
})
