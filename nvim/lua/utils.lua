_G.Util = {}

Util.mapluafn = function (mode, key, cmd)
  local value = '<cmd>lua vim.lsp.'..cmd..'<CR>'
  local opts = { noremap=true, silent=true }
  vim.api.nvim_buf_set_keymap(bufnr, mode, key, value, opts)
end

return Util
