_G.Util = {}

Util.mapluafn = function (mode, key, cmd)
  local value = '<cmd>lua vim.lsp.'..cmd..'<CR>'
  local opts = { noremap=true, silent=true }
  vim.api.nvim_buf_set_keymap(bufnr, mode, key, value, opts)
end

Util.merge_tables = function(t1, t2)
  for k,v in ipairs(t2) do
    table.insert(t1, v)
  end
  return t1
end

return Util
