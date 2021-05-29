local lspconfig = require 'lspconfig'
local util = require 'lspconfig/util'
local sign_def = vim.fn.sign_define
local u = require 'utils'

vim.lsp.set_log_level("error")


general_root = {".root", ".project.*", ".git/", ".gitignore", "README.md"}
py_root = {'venv/', 'requirements.txt', 'setup.py', 'pyproject.toml', 'setup.cfg'}
ts_js_root = {'jsconfig.json', 'tsconfig.json', 'package.json'}
c_cpp_root = {'compile_commands.json', 'build/', 'compile_flags.txt'}
go_root = {'go.sum', 'go.mod'}
swift_root = {'Package.swift'}


-- buffer-local setup
local on_attach = function(client, bufnr)
  print('Language Server Protocol started.')

  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
  vim.cmd("highlight! LspDiagnosticsDefaultError cterm=bold guifg=#E06C75")
  vim.cmd("highlight! LspDiagnosticsDefaultWarning cterm=bold guifg=#F5EA95")
  sign_def("LspDiagnosticsSignError", { text = "●"})
  sign_def("LspDiagnosticsSignWarning", { text = "●"})
  sign_def("LspDiagnosticsSignInformation", { text = "●"})
  sign_def("LspDiagnosticsSignHint", { text = "●"})

  u.mapluafn("n", "<F2>", "buf.declaration()")
  u.mapluafn("n", "<F3>", "buf.definition()")
  u.mapluafn("n", "<F4>", "buf.type_definition()")
  u.mapluafn("n", "<F5>", "buf.signature_help()")
  u.mapluafn("n", "K", "buf.hover()")
  u.mapluafn("n", "<Leader>imp", "buf.implementation()")
  u.mapluafn("n", "<Leader>ref", "buf.references()")
  u.mapluafn("n", "<Leader>rn", "buf.rename()")
  u.mapluafn("n", "<Leader>ds", "buf.document_symbol()")
  u.mapluafn("n", "<Leader>ws", "buf.workspace_symbol()")
  u.mapluafn("n","<Leader>ac",'buf.code_action()')

  u.mapluafn("n", "gn", "diagnostic.goto_next()")
  u.mapluafn("n","gp","diagnostic.goto_prev()")
end

-- override default config for all servers
lspconfig.util.default_config = vim.tbl_extend(
  "force",
  lspconfig.util.default_config,
  {
    log_level = vim.lsp.protocol.MessageType.Log;
    message_level = vim.lsp.protocol.MessageType.Log;
    on_attach = on_attach;
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
      return util.find_git_ancestor(fname) or util.root_pattern(u.merge_tables(py_root, general_root))
        or vim.fn.getcwd()
    end;
  };
}
lspconfig.clangd.setup{
  default_config = {
    cmd = { vim.fn.exepath('clangd'), '--clang-tidy', '--suggest-missing-includes' };
    filetypes = { "c", "cpp", "objc", "objcpp" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(u.merge_tables(c_cpp_root, general_root))
      or vim.fn.getcwd()
    end;
  };
}
lspconfig.tsserver.setup{
  default_config = {
    cmd = { vim.fn.exepath('typescript-language-server'), '--stdio', '--tsserver-log-file', '/tmp/ts.log' };
    filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(u.merge_tables(ts_js_root, general_root))
      or vim.fn.getcwd()
    end;
  };
}
lspconfig.html.setup{
  default_config = {
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
      return util.find_git_ancestor(fname) or util.root_pattern(u.merge_tables(go_root, general_root))
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
      return util.find_git_ancestor(fname) or util.root_pattern(u.merge_tables(swift_root, general_root))
      or vim.fn.getcwd()
    end;
  };
  settings = {
    serverArguments = { '--log-level', 'debug' };
    trace = { server = "messages"; };
  };
}
