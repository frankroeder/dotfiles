return function()
  local has_blink, blink = pcall(require, "blink.cmp")
  local has_cmp_lsp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

  local capabilities = vim.tbl_deep_extend(
    "force",
    {},
    vim.lsp.protocol.make_client_capabilities(),
    has_blink and blink.get_lsp_capabilities() or {},
    has_cmp_lsp and cmp_nvim_lsp.default_capabilities() or {}
  )

  -- TODO --
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
