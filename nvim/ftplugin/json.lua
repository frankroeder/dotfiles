vim.cmd("set conceallevel=0")

if vim.fn.executable("jq") then
  -- Format JSON with jq
  vim.keymap.set("n", "<Leader>fj", ":%!jq '.'<CR>")
end
