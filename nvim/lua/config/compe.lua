local compe = require('compe')
local keymap = require 'utils'.keymap

compe.setup {
  enabled = true;
  autocomplete = true;
  debug = false;
  min_length = 1;
  preselect = 'enable';
  throttle_time = 80;
  source_timeout = 200;
  incomplete_delay = 400;
  documentation = {
    border = { '', '' ,'', ' ', '', '', '', ' ' }, -- the border option is the same as `|help nvim_open_win|`
    winhighlight = "NormalFloat:CompeDocumentation,FloatBorder:CompeDocumentationBorder",
    max_width = 120,
    min_width = 60,
    max_height = math.floor(vim.o.lines * 0.3),
    min_height = 1,
  };

  source = {
    path = true;
    buffer = true;
    nvim_lsp = true;
    nvim_lua = true;
    treesitter = true;
    ultisnips = true;

    calc = false;
    tags = false;
    vsnip = false;
    luasnip = false;

    omni = {
      filetypes = {'tex'},
    },

  }
}
vim.o.completeopt = "menuone,noselect"

local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local check_back_space = function()
  local col = vim.fn.col('.') - 1
  return col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') ~= nil
end

-- Use (s-)tab to:
--- move to prev/next item in completion menuone
--- jump to prev/next snippet's placeholder
_G.tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return t "<C-n>"

  elseif vim.fn["UltiSnips#CanExpandSnippet"]() == 1 or vim.fn["UltiSnips#CanJumpForwards"]() == 1 then
    return t "<C-R>=UltiSnips#ExpandSnippetOrJump()<CR>"

  elseif check_back_space() then
    return t "<Tab>"

  else
    return vim.fn['compe#complete']()
  end
end

_G.s_tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return t "<C-p>"

  elseif vim.fn["UltiSnips#CanJumpBackwards"]() == 1 then
    return t "<C-R>=UltiSnips#JumpBackwards()<CR>"

  else
    -- If <S-Tab> is not working in your terminal, change it to <C-h>
    return t "<S-Tab>"
  end
end


vim.cmd("highlight link CompeDocumentation NormalFloat")

keymap("i", "<Tab>", "v:lua.tab_complete()", {expr = true})
keymap("s", "<Tab>", "v:lua.tab_complete()", {expr = true})
keymap("i", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})
keymap("s", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})

local keyopts =  { expr = true, noremap = true, silent = true }

-- keymap("n", "<CR>", "compe#confirm('<CR>')", keyopts)
keymap("i", "<C-Space>", "compe#complete()", keyopts)
keymap("i", "<C-e>", "compe#close('<C-e>')", keyopts)
keymap("i", "<C-f>", "compe#scroll({ 'delta': +4 })", keyopts)
keymap("i", "<C-d>", "compe#scroll({ 'delta': -4 })", keyopts)

require('nvim-autopairs').setup({
  disable_filetype = { "vim" },
})
require("nvim-autopairs.completion.compe").setup({
  map_cr = true, --  map <CR> on insert mode
  map_complete = true, -- it will auto insert `(` after select function or method item
  auto_select = false,  -- auto select first item
})
