-- Spell error: pick the first result
vim.keymap.set("n", "<Leader>z", [[z=1<CR><CR>]])

-- Fix spelling mistakes on the fly
vim.keymap.set("i", "<C-S>", [[<C-G>u<Esc>[s1z=`]a<C-G>u]])

-- Toggle between languages
local function toggle_spell()
  if vim.bo.spelllang == "en" then
    vim.o.spell = true
    vim.bo.spelllang = "de"
  elseif vim.bo.spelllang == "de" then
    vim.o.spell = false
    vim.o.spelllang = ""
  else
    vim.o.spell = true
    vim.bo.spelllang = "en"
  end
  print(string.format("spell checking language: %s", vim.bo.spelllang))
end

vim.keymap.set("n", "<Space>ts", function()
  toggle_spell()
end, { silent = true })
