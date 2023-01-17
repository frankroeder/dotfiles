-- TODO
-- local augroup = vim.api.nvim_create_augroup
-- local autocmd = vim.api.nvim_create_autocmd
--
-- local help_window = augroup("only_help_window")
-- autocmd("BufWinEnter", {
--   group = help_window,
--   command = [[<buffer> only]],
--   desc = "Automatically make help the only buffer",
-- })

vim.cmd [[
augroup HelpWin
  autocmd!
  autocmd BufWinEnter <buffer> only
augroup END
]]
