vim.wo.conceallevel = 0
vim.keymap.set("n", "<Space>cf", function()
  vim.lsp.buf.format { async = true }
end, { desc = "[c]ode [f]ormat" })
