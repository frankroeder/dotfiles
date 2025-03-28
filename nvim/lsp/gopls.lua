---@type vim.lsp.Config
return {
  cmd = { "gopls", "-logfile", "/tmp/gopls.log" },
  filetypes = { "go" },
  root_markers = { "go.sum", "go.mod" },
  init_options = {
    usePlaceholders = true,
    linkTarget = "pkg.go.dev",
    completionDocumentation = true,
    completeUnimported = true,
    deepCompletion = true,
    fuzzyMatching = true,
  },
}
