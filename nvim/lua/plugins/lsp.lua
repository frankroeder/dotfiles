local M = {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "cmp-nvim-lsp",
    { "williamboman/mason.nvim", build = ":MasonUpdate" },
    "williamboman/mason-lspconfig.nvim",
  },
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
    "clangd",
    "cssls",
    "ruff",
    -- "basedpyright",
    "html",
    "jedi_language_server",
    "lua_ls",
    "svelte",
    "tsserver",
  }
  mason.setup()
  mason_lspconfig.setup {
    ensure_installed = lsp_server,
  }
  mason_lspconfig.setup_handlers {
    -- default handler
    function(server_name)
      local opts = {}
      local success, req_opts = pcall(require, "plugins.lsp." .. server_name)
      if success then
        opts = req_opts
      end
      opts.capabilities = vim.tbl_deep_extend("force", {}, capabilities, opts.capabilities or {})
      lspconfig[server_name].setup(opts)
    end,
    -- ["sourcekit"] = function ()
    --   lspconfig["sourcekit"].setup(require "plugins.lsp.sourcekit")
    -- end
  }
end

return M
