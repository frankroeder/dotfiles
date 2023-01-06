return {
  cmd = { vim.fn.exepath "elixir-ls" },
  settings = {
    elixirLS = {
      dialyzerEnabled = false,
      fetchDeps = false,
    },
  },
}
