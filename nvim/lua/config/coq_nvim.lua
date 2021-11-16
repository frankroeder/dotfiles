local remap = vim.api.nvim_set_keymap
local npairs = require('nvim-autopairs')

vim.g.coq_settings = {
  auto_start = "shut-up",
  clients = {
    tmux = { enabled = true },
    tree_sitter = { enabled = true },
    tags = { enabled = false },
  },
  keymap =  {
    pre_select = false,
    bigger_preview = null,
    jump_to_mark = "<C-L>",
  },
  display = {
    ghost_text = {
      enabled = true,
      highlight_group = 'Comment'
    },
    icons = {
      mappings = {
        -- vscode-like pictograms
        Text = "",
        Method = "",
        Function = "",
        Constructor = "",
        Field = "ﰠ",
        Variable = "",
        Class = "ﴯ",
        Interface = "",
        Module = "",
        Property = "ﰠ",
        Unit = "塞",
        Value = "",
        Enum = "",
        Keyword = "",
        Snippet = "",
        Color = "",
        File = "",
        Reference = "",
        Folder = "",
        EnumMember = "",
        Constant = "",
        Struct = "פּ",
        Event = "",
        Operator = "",
        TypeParameter = ""
      },
    },
  },
}

require("coq_3p") {
  { src = "nvimlua", short_name = "Lua" },
  { src = "vimtex", short_name = "Tex" },
}

npairs.setup({
  map_bs = false,
  map_cr = false,
  disable_filetype = { "vim", "help" },
})
_G.MUtils= {}

MUtils.CR = function()
  if vim.fn.pumvisible() ~= 0 then
    if vim.fn.complete_info({ 'selected' }).selected ~= -1 then
      return npairs.esc('<C-Y>')
    else
      return npairs.esc('<C-E>') .. npairs.autopairs_cr()
    end
  else
    return npairs.autopairs_cr()
  end
end
remap('i', '<CR>', 'v:lua.MUtils.CR()', { expr = true, noremap = true })

MUtils.BS = function()
  if vim.fn.pumvisible() ~= 0 and vim.fn.complete_info({ 'mode' }).mode == 'eval' then
    return npairs.esc('<C-E>') .. npairs.autopairs_bs()
  else
    return npairs.autopairs_bs()
  end
end
remap('i', '<BS>', 'v:lua.MUtils.BS()', { expr = true, noremap = true })
