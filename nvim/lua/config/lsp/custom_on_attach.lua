local buf_keymap = require("utils").buf_keymap

return function(client, bufnr)
  -- lsp
  vim.keymap.set("n", "K", vim.lsp.buf.hover, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("i", "<C-H>", vim.lsp.buf.signature_help, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "<Space>rn", vim.lsp.buf.rename, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "<Space>ca", vim.lsp.buf.code_action, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "<Space>cf", function() vim.lsp.buf.format {async = true} end, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "<Space>rf", vim.lsp.buf.references, { noremap = true, silent = true, buffer = bufnr })
  -- diagnostic
  vim.keymap.set("n", "gn", function() vim.diagnostic.goto_next { float = true } end, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "gp", function() vim.diagnostic.goto_prev { float = true } end, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "<Space>ld", function() vim.diagnostic.open_float(0, {scope="line"}) end, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "<Space>ll", vim.diagnostic.setloclist, { noremap = true, silent = true, buffer = bufnr })
end
