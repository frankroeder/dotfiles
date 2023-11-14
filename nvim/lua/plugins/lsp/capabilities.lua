return function(cmp_nvim_lsp)
  local capabilities = cmp_nvim_lsp.default_capabilities()
  capabilities.textDocument.completion.completionItem = {
    snippetSupport = true,
    labelDetailsSupport = true,
    documentationFormat = { "markdown", "plaintext" },
    insertReplaceSupport = true,
    commitCharactersSupport = true,
    resolveSupport = {
      properties = { "documentation", "detail", "additionalTextEdits" },
    },
  }
  return capabilities
end
