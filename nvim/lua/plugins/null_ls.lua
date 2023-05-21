local M = {
  "jose-elias-alvarez/null-ls.nvim",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
}

function M.config()
  local status_ok, null_ls = pcall(require, "null-ls")
  if not status_ok then
    return
  end

  local fmt = null_ls.builtins.formatting
  local diagnostics = null_ls.builtins.diagnostics
  local code_actions = null_ls.builtins.code_actions

  null_ls.setup {
    sources = {
      fmt.ruff,
      fmt.black,
      fmt.clang_format,
      fmt.eslint,
      fmt.gofmt,
      fmt.stylua,
      fmt.jq,
      diagnostics.eslint,
      diagnostics.ruff,
      code_actions.gitsigns,
    },
  }
end

return M
