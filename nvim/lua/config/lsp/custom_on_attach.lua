return function(client, bufnr)
  vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
  -- lsp
  vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr, desc="Hover documentation" })
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr, desc="[g]oto [D]eclaration" })
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr, desc="[g]oto [d]efintion"  })
  vim.keymap.set("i", "<C-H>", vim.lsp.buf.signature_help, { buffer = bufnr, desc="Signature [H]elp" })

  vim.keymap.set("n", "<Space>gI", vim.lsp.buf.implementation, { buffer = bufnr, desc="[g]oto [i]mplementation" })
  vim.keymap.set("n", "<Space>rn", vim.lsp.buf.rename, { buffer = bufnr, desc="[r]e[n]ame" })
  vim.keymap.set("n", "<Space>ca", vim.lsp.buf.code_action, { buffer = bufnr, desc="[c]ode [a]ction" })
  vim.keymap.set("n", "<Space>cf", function() vim.lsp.buf.format {async = true} end, { buffer = bufnr, desc="[c]ode [f]ormat" })
  vim.keymap.set("n", "<Space>rf", vim.lsp.buf.references, { buffer = bufnr, desc="[r]e[f]erence" })

  -- diagnostic
  vim.keymap.set("n", "gn", function() vim.diagnostic.goto_next { float = true } end, { buffer = bufnr, desc="[g]oto [n]ext diagnostic" })
  vim.keymap.set("n", "gp", function() vim.diagnostic.goto_prev { float = true } end, { buffer = bufnr, desc="[g]oto [p]revious diagnostic" })
  vim.keymap.set("n", "<Space>ld", function() vim.diagnostic.open_float(0, {scope="line"}) end, { buffer = bufnr, desc="Show [l]ine [d]iagnostic" })
  vim.keymap.set("n", "<Space>ll", vim.diagnostic.setloclist, { buffer = bufnr, desc="Show diagnostic [l]ocation [l]ist" })

  if client.server_capabilities.codeLensProvider then
    vim.cmd [[autocmd BufEnter,CursorHold,InsertLeave <buffer> lua vim.lsp.codelens.refresh() ]]
    vim.lsp.codelens.refresh()
  end

  -- LSP document highlighting
  if client.server_capabilities.documentHighlightProvider then
    local group = 'lsp_document_highlight'
    vim.api.nvim_create_augroup(
      group,
      { clear = true }
    )
    vim.api.nvim_create_autocmd('CursorHold', {
      callback = vim.lsp.buf.document_highlight,
      buffer = vim.api.nvim_get_current_buf(),
      group = group,
    })
    vim.api.nvim_create_autocmd('CursorMoved', {
      callback = vim.lsp.buf.clear_references,
      buffer = vim.api.nvim_get_current_buf(),
      group = group,
    })
  end
end
