local lsc = require('lspconfig')
local nls = require('null-ls')

local fmt = nls.builtins.formatting
local diagnostics = nls.builtins.diagnostics

-- Configuring null-ls
nls.config({
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
  },
})

require("lspconfig")["null-ls"].setup {}
