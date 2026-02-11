---@type vim.lsp.Config
return {
  cmd = { "elixir-ls" },
  filetypes = { "elixir", "heex", "eex" },
  settings = {
    elixirLS = {
      dialyzerEnabled = false,
      fetchDeps = false,
    },
  },
}
