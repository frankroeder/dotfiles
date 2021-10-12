local lspconfig = require 'lspconfig'
local util = require 'lspconfig/util'
local sign_def = vim.fn.sign_define
local buf_keymap = require 'utils'.buf_keymap
local merge_tables = require 'utils'.merge_tables

vim.lsp.set_log_level("error")

general_root = {".root", ".project.*", ".git/", ".gitignore", "README.md"}
py_root = {'venv/', 'requirements.txt', 'setup.py', 'pyproject.toml', 'setup.cfg'}
ts_js_root = {'jsconfig.json', 'tsconfig.json', 'package.json'}
c_cpp_root = {'compile_commands.json', 'build/', 'compile_flags.txt', '.clangd'}
go_root = {'go.sum', 'go.mod'}
swift_root = {'Package.swift'}

-- buffer setup
local custom_on_attach = function(client, bufnr)
  print('Language Server Protocol started.')

  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
  vim.cmd("highlight! LspDiagnosticsDefaultError cterm=bold guifg=#E06C75")
  vim.cmd("highlight! LspDiagnosticsDefaultWarning cterm=bold guifg=#F5EA95")
  sign_def("LspDiagnosticsSignError", { text = "●"})
  sign_def("LspDiagnosticsSignWarning", { text = "●"})
  sign_def("LspDiagnosticsSignInformation", { text = "●"})
  sign_def("LspDiagnosticsSignHint", { text = "●"})

  buf_keymap(bufnr, "n", "K", [[<cmd>lua vim.lsp.buf.hover()<CR>]])
  buf_keymap(bufnr, "n", "gD", [[<cmd>lua vim.lsp.buf.declaration()<CR>]])
  buf_keymap(bufnr, "n", "gd", [[<cmd>lua vim.lsp.buf.definition()<CR>]])
  buf_keymap(bufnr, "n", "<Space>sh", [[<cmd>lua vim.lsp.buf.signature_help()<CR>]])
  buf_keymap(bufnr, "n", "<Leader>rn", [[<cmd>lua vim.lsp.buf.rename()<CR>]])
  buf_keymap(bufnr, "n", "<Leader>ca", [[<cmd>lua vim.lsp.buf.code_action()<CR>]])
  buf_keymap(bufnr, "n", "<Space>cf", [[<cmd>lua vim.lsp.buf.formatting()<CR>]])
  -- buf_keymap(bufnr, "n", "<F4>", [[<cmd>lua vim.lsp.buf.type_definition()<CR>]])
  -- buf_keymap(bufnr, "n", "<Leader>imp", [[<cmd>lua vim.lsp.buf.implementation()<CR>]])
  -- buf_keymap(bufnr, "n", "<Leader>ref", [[<cmd>lua vim.lsp.buf.references()<CR>]])
  -- buf_keymap(bufnr, "n", "<Leader>ds", [[<cmd>lua vim.lsp.buf.document_symbol()<CR>]])
  -- buf_keymap(bufnr, "n", "<Leader>ws", [[<cmd>lua vim.lsp.buf.workspace_symbol()<CR>]])

  -- diagnostic
  buf_keymap(bufnr, "n", "gn", [[<cmd>lua vim.lsp.diagnostic.goto_next()<CR>]])
  buf_keymap(bufnr, "n", "gp", [[<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>]])
  buf_keymap(bufnr, "n", "<Space>ld", [[<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>]])
  buf_keymap(bufnr, "n", "<Space>ll", [[<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>]])

  require "lsp_signature".on_attach({
    bind = true,
    hint_enable = false,
    handler_opts = {
      border = "single"   -- double, single, shadow, none
    },
    always_trigger = false,
    toggle_key = "<C-x>"
  }, bufnr)
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.documentationFormat = {"markdown", "plaintext"}
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.completion.completionItem.preselectSupport = true
capabilities.textDocument.completion.completionItem.insertReplaceSupport = true
capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
capabilities.textDocument.completion.completionItem.deprecatedSupport = true
capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
capabilities.textDocument.completion.completionItem.tagSupport = {valueSet = {1}}
capabilities.textDocument.completion.completionItem.resolveSupport = {
  properties = {
    'documentation',
    'detail',
    'additionalTextEdits',
  }
}
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)

-- override default config for all servers
lspconfig.util.default_config = vim.tbl_extend(
  "force",
  lspconfig.util.default_config,
  {
    log_level = vim.lsp.protocol.MessageType.Log;
    message_level = vim.lsp.protocol.MessageType.Log;
    flags = {
      debounce_text_changes = 150,
    };
    on_attach = custom_on_attach;
    capabilities = capabilities;
  }
)
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
  vim.lsp.diagnostic.on_publish_diagnostics, {
    underline = false,
    virtual_text = false,
    signs = function(bufnr, client_id)
      local ok, result = pcall(vim.api.nvim_buf_get_var, bufnr, 'show_signs')
      -- No buffer local variable set, so just enable by default
      if not ok then
        return true
      end

      return result
    end,
    update_in_insert = true,
  }
)
lspconfig.pyright.setup{
  default_config = {
    cmd = { vim.fn.exepath("pyright-langserver"), "--stdio" };
    filetypes = { "python" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(merge_tables(py_root, general_root))
        or vim.fn.getcwd()
    end;
  };
}
lspconfig.clangd.setup{
  default_config = {
    cmd = { vim.fn.exepath('clangd'), '--clang-tidy', '--suggest-missing-includes' };
    filetypes = { "c", "cpp", "objc", "objcpp" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(merge_tables(c_cpp_root, general_root))
        or vim.fn.getcwd()
    end;
  };
}
lspconfig.tsserver.setup{
  default_config = {
    cmd = { vim.fn.exepath('typescript-language-server'), '--stdio', '--tsserver-log-file', '/tmp/ts.log' };
    filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(merge_tables(ts_js_root, general_root))
        or vim.fn.getcwd()
    end;
  };
}
lspconfig.html.setup{
  default_config = {
    cmd = { vim.fn.exepath('html-languageserver'), '--stdio' };
    filetypes = { "html" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or vim.fn.getcwd()
    end;
  };
}
lspconfig.cssls.setup{
  default_config = {
    filetypes = {"css", "scss", "sass", "less"};
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or vim.fn.getcwd()
    end;
  };
}

lspconfig.gopls.setup{
  default_config = {
    cmd = { vim.fn.exepath('gopls'), '-logfile', '/tmp/gopls.log' };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(merge_tables(go_root, general_root))
        or vim.fn.getcwd()
    end;
  };
  init_options = {
    usePlaceholders=true;
    linkTarget="pkg.go.dev";
    completionDocumentation=true;
    completeUnimported=true;
    deepCompletion=true;
    fuzzyMatching=true;
  };
}
lspconfig.sourcekit.setup{
  cmd = { "xcrun", vim.fn.exepath('sourcekit-lsp') };
  default_config = {
    filetypes = { "swift", "c", "cpp", "objective-c", "objective-cpp" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(merge_tables(swift_root, general_root))
        or vim.fn.getcwd()
    end;
  };
  settings = {
    serverArguments = { '--log-level', 'debug' };
    trace = { server = "messages"; };
  };
}
