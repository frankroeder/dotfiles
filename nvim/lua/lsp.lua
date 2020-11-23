local lspconfig = require'lspconfig'
local util = require 'lspconfig/util'

vim.lsp.set_log_level("error")

function table.merge(t1, t2)
  for k,v in ipairs(t2) do
    table.insert(t1, v)
  end
  return t1
end

general_root = {".root", ".project.*", ".git/", ".gitignore", "README.md"}
py_root = {'venv/', 'requirements.txt', 'setup.py'}
ts_js_root = {'jsconfig.json', 'tsconfig.json', 'package.json'}
c_cpp_root = {'compile_commands.json', 'build/', 'compile_flags.txt'}
go_root = {'go.sum', 'go.mod'}
swift_root = {'Package.swift'}

-- buffer-local setup
local on_attach = function(client, bufnr)
  print("LSP started.");

  local function mapluafn(mode, key, cmd)
    local value = '<cmd>lua vim.lsp.'..cmd..'<CR>'
    local opts = { noremap=true, silent=true }
    vim.api.nvim_buf_set_keymap(bufnr, mode, key, value, opts)
  end

  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  vim.cmd("highlight! LspDiagnosticsDefaultError cterm=bold guifg=#E06C75")
  vim.cmd("highlight! LspDiagnosticsDefaultWarning cterm=bold guifg=#F5EA95")
  vim.fn.sign_define("LspDiagnosticsSignError", { text = "●"})
  vim.fn.sign_define("LspDiagnosticsSignWarning", { text = "●"})
  vim.fn.sign_define("LspDiagnosticsSignInformation", { text = "●"})
  vim.fn.sign_define("LspDiagnosticsSignHint", { text = "●"})

  mapluafn("n", "<F2>", "buf.declaration()")
  mapluafn("n", "<F3>", "buf.definition()")
  mapluafn("n", "<F4>", "buf.type_definition()")
  mapluafn("n", "<F5>", "buf.signature_help()")
  mapluafn("n", "<F12>", "buf.formatting()")
  mapluafn("n", "K", "buf.hover()")
  mapluafn("n", "<Leader>imp", "buf.implementation()")
  mapluafn("n", "<Leader>ref", "buf.references()")
  mapluafn("n", "<Leader>rn", "buf.rename()")
  mapluafn("n", "<Leader>ds", "buf.document_symbol()")
  mapluafn("n", "<Leader>ws", "buf.workspace_symbol()")
  mapluafn("n","<Leader>ac",'buf.code_action()')

  mapluafn("n", "gn", "diagnostic.goto_next()")
  mapluafn("n","gp","diagnostic.goto_prev()")
end

-- override default config
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

lspconfig.pyls.setup{
  enable = true;
  default_config = {
    cmd = { vim.fn.exepath('pyls'), '--log-file' , '/tmp/pyls.log' };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(py_root, general_root))
      or vim.fn.getcwd()
    end;
  };
  settings = {
    pyls = {
      plugins = {
        preload = { modules = { "numpy", "torch" }; };
        configurationSources = { "pyflakes" };
      };
    };
  };
}
lspconfig.clangd.setup{
  default_config = {
    cmd = { vim.fn.exepath('clangd'), '--clang-tidy', '--suggest-missing-includes' };
    filetypes = { "c", "cpp", "objc", "objcpp" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(c_cpp_root, general_root))
      or vim.fn.getcwd()
    end;
  };
}
lspconfig.tsserver.setup{
  default_config = {
    cmd = { vim.fn.exepath('typescript-language-server'), '--stdio', '--tsserver-log-file', '/tmp/ts.log' };
    filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(ts_js_root, general_root))
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
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(go_root, general_root))
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
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(swift_root, general_root))
      or vim.fn.getcwd()
    end;
  };
  settings = {
    serverArguments = { '--log-level', 'debug' };
    trace = { server = "messages"; };
  };
}
