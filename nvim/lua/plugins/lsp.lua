local M = {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "cmp-nvim-lsp", "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
}

function M.config()
  local lsp_status_ok, lspconfig = pcall(require, "lspconfig")
  if not lsp_status_ok then
    return
  end

  local mason_status_ok, mason = pcall(require, "mason")
  if not mason_status_ok then
    return
  end

  local mason_lspconfig_status_ok, mason_lspconfig = pcall(require, "mason-lspconfig")
  if not mason_lspconfig_status_ok then
    return
  end

  vim.lsp.set_log_level "error"

  local cmp_status_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if not cmp_status_ok then
    return
  end

  local capabilities = require "plugins.lsp.capabilities"(cmp_nvim_lsp)

  local lsp_defaults = {
    log_level = vim.lsp.protocol.MessageType.Log,
    message_level = vim.lsp.protocol.MessageType.Log,
    flags = {
      debounce_text_changes = 150,
    },
    capabilities = capabilities,
    on_attach = require "plugins.lsp.custom_on_attach",
  }

  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
    border = "rounded",
    close_events = { "CursorMoved", "BufHidden", "InsertCharPre" },
  })

  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
    border = "rounded",
  })

  -- override default config for all servers
  lspconfig.util.default_config =
    vim.tbl_deep_extend("force", lspconfig.util.default_config, lsp_defaults)
  require "plugins.lsp.diagnostics"

  local lsp_server = {
    "pyright",
    "clangd",
    "tsserver",
    "html",
    "cssls",
    "gopls",
    "sourcekit",
    "svelte",
    "elixirls",
    "lua_ls",
  }
  mason.setup()
  mason_lspconfig.setup {
    ensure_installed = lsp_server,
  }
  mason_lspconfig.setup_handlers {
    function(server)
      local opts = {}
      local success, req_opts = pcall(require, "plugins.lsp." .. server)
      if success then
        opts = req_opts
      end
      lspconfig[server].setup(opts)
    end
  }
end

return M
