local remap = vim.api.nvim_set_keymap
local npairs = require('nvim-autopairs')

vim.g.coq_settings = {
  ['auto_start'] = "shut-up",
  ['clients.tmux.enabled'] = true,
  ['clients.tree_sitter.enabled'] = true,
  ['clients.tags.enabled'] = false,
  ['display.ghost_text.enabled'] = true,
}
require("coq_3p") {
  { src = "nvimlua", short_name = "Lua" },
  { src = "vimtex", short_name = "Tex" },
  -- { src = "copilot", short_name = "COP", tmp_accept_key = "<c-r>" },
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
