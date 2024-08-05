-- Resolve spell error by picking the first suggestion
vim.keymap.set("n", "<Leader>z", [[z=1<CR><CR>]])

-- Fix spelling mistakes on the fly (insert mode)
vim.keymap.set("i", "<C-S>", [[<C-G>u<Esc>[s1z=`]a<C-G>u]])

-- Toggle between languages
local function toggle_spell()
  if vim.opt_local.spell:get() then
    if vim.opt_local.spelllang:get()[1] == "en_us" then
      vim.opt_local.spelllang = "de"
    elseif vim.opt_local.spelllang:get()[1] == "de" then
      vim.opt_local.spell = false
      vim.opt_local.spelllang = ""
    end
  else
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
  end
  print(string.format("spell checking language: %s", vim.opt_local.spelllang:get()[1]))
end

vim.opt.spelloptions:append "camel"
vim.keymap.set("n", "<Space>ts", function()
  toggle_spell()
end, { silent = true })
