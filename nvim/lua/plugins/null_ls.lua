local M = { "jose-elias-alvarez/null-ls.nvim",  event = { "BufReadPre", "BufNewFile" } }

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
      fmt.ruff.with {
        command = vim.fn.exepath "ruff",
      },
      fmt.clang_format.with {
        command = vim.fn.exepath "clang-format",
      },
      fmt.eslint.with {
        command = vim.fn.exepath "eslint",
      },
      fmt.gofmt.with {
        command = vim.fn.exepath "gofmt",
      },
      fmt.stylua.with {
        command = vim.fn.exepath "stylua",
      },
      fmt.jq.with {
        command = vim.fn.exepath "jq",
      },
      diagnostics.eslint,
      diagnostics.ruff,
      code_actions.gitsigns,
    },
  }
end

return M
