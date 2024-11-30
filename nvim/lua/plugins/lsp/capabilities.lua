return function()
  local has_blink, blink = pcall(require, "blink.cmp")

  local capabilities = vim.tbl_deep_extend(
    "force",
    {},
    vim.lsp.protocol.make_client_capabilities(),
    has_blink and blink.get_lsp_capabilities() or {}
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
