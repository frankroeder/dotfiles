local fzf_status_ok, fzf = pcall(require, "fzf-lua")
if not fzf_status_ok then
  return
end

fzf.setup {
  winopts = { split = "aboveleft new" },
  files = {
    git_icons = false,
    file_icons = false,
  }
}

local is_git_repo = vim.fn.system "git rev-parse --is-inside-work-tree 2>/dev/null" == 0
-- files
if is_git_repo then
  vim.keymap.set("n", "<C-T>", [[<cmd>lua require('fzf-lua').git_files()<CR>]])
else
  vim.keymap.set("n", "<C-T>", [[<cmd>lua require('fzf-lua').files()<CR>]])
end
-- file lines
vim.keymap.set("n", "<C-F>", [[<cmd>lua require('fzf-lua').grep_project()<CR>]])
-- vim buffers
vim.keymap.set("n", "<C-B>", [[<cmd>lua require('fzf-lua').buffers()<CR>]])
-- buffer lines
vim.keymap.set("n", "<C-P>", [[<cmd>lua require('fzf-lua').lgrep_curbuf()<CR>]])
-- colorschemes with preview
vim.keymap.set("n", "<Leader>t", [[<cmd>lua require('fzf-lua').colorschemes()<CR>]])
-- help tags
vim.keymap.set("n", "<C-H>", [[<cmd>lua require('fzf-lua').help_tags()<CR>]])
-- vim commands
vim.keymap.set("n", "<Leader>:", [[<cmd>lua require('fzf-lua').commands()<CR>]])
-- git commits
vim.keymap.set("n", "<Leader>g", [[<cmd>lua require('fzf-lua').git_commits()<CR>]])
-- defined keymaps
vim.keymap.set("n", "<Leader>m", [[<cmd>lua require('fzf-lua').keymaps()<CR>]])
-- vim marks
vim.keymap.set("n", "<Leader>k", [[<cmd>lua require('fzf-lua').marks()<CR>]])
vim.keymap.set(
  -- vim command history
  "n",
  "<Leader>h",
  [[<cmd>lua require('fzf-lua').command_history()<CR>]]
)
