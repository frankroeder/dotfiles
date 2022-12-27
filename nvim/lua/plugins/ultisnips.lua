local M = { "SirVer/ultisnips" }

function M.config()
  vim.g.UltiSnipsExpandTrigger = "<C-L>"
  vim.g.UltiSnipsJumpForwardTrigger = "<C-J>"
  vim.g.UltiSnipsJumpBackwardTrigger = "<C-K>"

  vim.g.UltiSnipsEnableSnipMate = 0
  vim.g.snips_author = "Frank Roeder"
  vim.g.ultisnips_javascript = {}
  vim.g.ultisnips_javascript["keyword-spacing"] = "always"
  vim.g.ultisnips_javascript["semi"] = "never"
  vim.g.ultisnips_javascript["space-before-function-paren"] = "always"

  vim.g.UltiSnipsSnippetDirectories = { vim.fn.getenv "DOTFILES" .. "/nvim/ultisnips" }
end

return M
