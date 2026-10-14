-- Resolve spell error by picking the first suggestion
vim.keymap.set("n", "<Leader>z", [[z=1<CR><CR>]])

-- Fix spelling mistakes on the fly (insert mode)
vim.keymap.set("i", "<C-S>", [[<C-G>u<Esc>[s1z=`]a<C-G>u]])

-- Toggle spell checking, English and German at once
local function toggle_spell()
  vim.opt_local.spell = not vim.opt_local.spell:get()
  vim.opt_local.spelllang = "en_us,de"
  print("spell checking: " .. (vim.opt_local.spell:get() and "en_us,de" or "off"))
end

vim.opt.spelloptions:append "camel"
vim.keymap.set("n", "<Space>ts", function()
  toggle_spell()
end, { silent = true })
