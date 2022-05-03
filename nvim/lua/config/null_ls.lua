local nls = require('null-ls')

local fmt = nls.builtins.formatting
local diagnostics = nls.builtins.diagnostics
local code_actions = nls.builtins.code_actions


-- Configuring null-ls
nls.setup({
  save_after_format = false,
  sources = {
    fmt.yapf.with({
      command = vim.fn.exepath("yapf"),
    })
    ,
    fmt.clang_format.with({
      command = vim.fn.exepath("clang-format")
    }),
    fmt.eslint.with({
      command = vim.fn.exepath("eslint")
    }),
    fmt.gofmt.with({
      command = vim.fn.exepath("gofmt")
    }),
    diagnostics.eslint,
    code_actions.gitsigns,
  },
})
