if vim.opt.diff:get() then
  vim.keymap.set("n", "gdl", ":diffget LOCAL<CR>")
  vim.keymap.set("n", "gdb", ":diffget BASE<CR>")
  vim.keymap.set("n", "gdr", ":diffget REMOTE<CR>")
  vim.keymap.set("n", "gq", ":wqa<CR>")
end
