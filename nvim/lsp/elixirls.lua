---@type vim.lsp.Config
return {
  cmd = { "elixir-ls" },
  filetypes = { "css", "scss", "less" },
  settings = {
    elixirLS = {
      dialyzerEnabled = false,
      fetchDeps = false,
    },
  },
}
