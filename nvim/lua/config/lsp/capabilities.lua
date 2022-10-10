return function(cmp_nvim_lsp)
  local basic_capabilities = vim.lsp.protocol.make_client_capabilities()
  basic_capabilities.textDocument.completion.completionItem = {
    documentationFormat = { "markdown", "plaintext" },
    commitCharactersSupport = true,
    resolveSupport = {
      properties = { 'documentation', 'detail', 'additionalTextEdits' },
    }
  }
  return cmp_nvim_lsp.update_capabilities(basic_capabilities)
end
