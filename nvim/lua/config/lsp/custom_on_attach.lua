local buf_keymap = require("utils").buf_keymap

return function(client, bufnr)
  -- lsp
  buf_keymap(bufnr, "n", "K", [[<cmd>lua vim.lsp.buf.hover()<CR>]])
  buf_keymap(bufnr, "n", "gD", [[<cmd>lua vim.lsp.buf.declaration()<CR>]])
  buf_keymap(bufnr, "n", "gd", [[<cmd>lua vim.lsp.buf.definition()<CR>]])
  buf_keymap(bufnr, "i", "<C-H>", [[<cmd>lua vim.lsp.buf.signature_help()<CR>]])
  buf_keymap(bufnr, "n", "<Space>rn", [[<cmd>lua vim.lsp.buf.rename()<CR>]])
  buf_keymap(bufnr, "n", "<Space>ca", [[<cmd>lua vim.lsp.buf.code_action()<CR>]])
  buf_keymap(bufnr, "n", "<Space>cf", [[<cmd>lua vim.lsp.buf.formatting()<CR>]])
  buf_keymap(bufnr, "n", "<Space>rf", [[<cmd>lua vim.lsp.buf.references()<CR>]])
  -- diagnostic
  buf_keymap(bufnr, "n", "gn", [[<cmd>lua vim.diagnostic.goto_next { float = true }<CR>]])
  buf_keymap(bufnr, "n", "gp", [[<cmd>lua vim.diagnostic.goto_prev { float = true }<CR>]])
  buf_keymap(bufnr, "n", "<Space>ld", [[<cmd>lua vim.diagnostic.open_float(0, {scope="line"})<CR>]])
  buf_keymap(bufnr, "n", "<Space>ll", [[<cmd>lua vim.diagnostic.setloclist()<CR>]])
end
