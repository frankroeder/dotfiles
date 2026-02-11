local function on_attach(client, bufnr)
  if not client then
    return
  end
  if client.server_capabilities.completionProvider then
    vim.api.nvim_set_option_value("omnifunc", "v:lua.vim.lsp.omnifunc", { buf = bufnr })
    vim.api.nvim_set_option_value("formatexpr", "v:lua.vim.lsp.formatexpr()", { buf = bufnr })
  end
  vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr, desc = "Hover documentation" })
  vim.keymap.set(
    "n",
    "gD",
    [[<cmd>lua require('fzf-lua').lsp_declarations()<CR>]],
    { buffer = bufnr, desc = "[g]oto [D]eclaration" }
  )
  vim.keymap.set(
    "n",
    "gd",
    [[<cmd>lua require('fzf-lua').lsp_definitions()<CR>]],
    { buffer = bufnr, desc = "[g]oto [d]efintion" }
  )
  vim.keymap.set(
    "i",
    "<C-H>",
    vim.lsp.buf.signature_help,
    { buffer = bufnr, desc = "Signature [H]elp" }
  )
  vim.keymap.set(
    "n",
    "<Space>gI",
    [[<cmd>lua require('fzf-lua').lsp_implementations()<CR>]],
    { buffer = bufnr, desc = "[g]oto [i]mplementation" }
  )
  vim.keymap.set("n", "<Space>rn", vim.lsp.buf.rename, { buffer = bufnr, desc = "[r]e[n]ame" })
  vim.keymap.set(
    "n",
    "<Space>ca",
    [[<cmd>lua require('fzf-lua').lsp_code_actions()<CR>]],
    { buffer = bufnr, desc = "[c]ode [a]ction" }
  )
  vim.keymap.set(
    "n",
    "<Space>rf",
    [[<cmd>lua require('fzf-lua').lsp_references()<CR>]],
    { buffer = bufnr, desc = "[r]e[f]erence" }
  )
  -- diagnostic
  vim.keymap.set("n", "gn", function()
    vim.diagnostic.jump { count = 1, float = true }
  end, { buffer = bufnr, desc = "[g]oto [n]ext diagnostic" })
  vim.keymap.set("n", "gp", function()
    vim.diagnostic.jump { count = -1, float = true }
  end, { buffer = bufnr, desc = "[g]oto [p]revious diagnostic" })
  vim.keymap.set("n", "<Space>ld", function()
    vim.diagnostic.open_float(0, { scope = "line" })
  end, { buffer = bufnr, desc = "Show [l]ine [d]iagnostic" })
  vim.keymap.set(
    "n",
    "<Space>ll",
    [[<cmd>lua require('fzf-lua').diagnostics_document()<CR>]],
    { buffer = bufnr, desc = "Show diagnostics" }
  )
  vim.keymap.set(
    "n",
    "<Leader>ll",
    vim.diagnostic.setloclist,
    { buffer = bufnr, desc = "Show diagnostic [l]ocation [l]ist" }
  )

  vim.keymap.set("n", "<Leader>li", [[:LspInfo<CR>]], { buffer = bufnr, desc = "[l]sp[i]nfo" })

  vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  vim.keymap.set("n", "<leader>ti", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
  end)

  if client and client.server_capabilities.documentHighlightProvider then
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
      buffer = bufnr,
      callback = vim.lsp.buf.document_highlight,
    })

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      buffer = bufnr,
      callback = vim.lsp.buf.clear_references,
    })
  end

  if client.name == "ruff" then
    -- Disable hover in favor of jedi
    client.server_capabilities.hoverProvider = false
  end
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)
capabilities = vim.tbl_deep_extend("force", capabilities, {
  textDocument = {
    foldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true,
    },
  },
})

vim.lsp.config("*", {
  capabilities = capabilities,
  on_attach = on_attach,
})
vim.lsp.enable {
  "clangd",
  "cssls",
  "ruff",
  "html_ls",
  "lua_ls",
  "svelte_ls",
  "ts_ls",
  "basedpyright",
  "typst_ls",
  -- "ty",
}

vim.lsp.set_log_level "error"

vim.diagnostic.config {
  virtual_text = false,
  underline = false,
  update_in_insert = false,
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.HINT] = "",
      [vim.diagnostic.severity.INFO] = "",
    },
  },
}

vim.api.nvim_create_user_command("LspLog", function()
  vim.cmd.split(vim.lsp.log.get_filename())
end, {
  desc = "Get all the lsp logs",
})
vim.api.nvim_create_user_command("LspInfo", function()
  vim.cmd "silent checkhealth vim.lsp"
end, {
  desc = "Get all the information about all LSP attached",
})

-- Stop all lsp clients when quitting vim
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    vim.iter(vim.lsp.get_clients()):each(function(client)
      client:stop()
    end)
  end,
})
