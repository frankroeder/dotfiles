local nvim_lsp = require'nvim_lsp'
local util = require 'nvim_lsp/util'

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

  local opts = { noremap=true, silent=true }
  local function mapluafn(mode, key, cmd)
    local value = '<cmd>lua vim.lsp.buf.'..cmd..'<CR>'
    vim.api.nvim_buf_set_keymap(bufnr, mode, key, value, opts)
  end

  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  require'diagnostic'.on_attach(client)
  vim.cmd("highlight! LspDiagnosticsError cterm=bold guifg=#E06C75")
  vim.cmd("highlight! LspDiagnosticsWarning cterm=bold guifg=#F5EA95")
  vim.fn.sign_define("LspDiagnosticsErrorSign", { text = "●", texthl = "LspDiagnosticsError" })
  vim.fn.sign_define("LspDiagnosticsWarningSign", { text = "●", texthl = "LspDiagnosticsWarning" })
  vim.fn.sign_define("LspDiagnosticsInformationSign", { text = "●", texthl = "LspDiagnosticsInformation" })
  vim.fn.sign_define("LspDiagnosticsHintSign", { text = "●", texthl = "LspDiagnosticsHint" })
  vim.g.diagnostic_enable_underline = 0
  vim.g.diagnostic_auto_popup_while_jump = 1
  vim.g.diagnostic_insert_delay = 1

  mapluafn("n", "<F2>", "declaration()")
  mapluafn("n", "<F3>", "definition()")
  mapluafn("n", "<F4>", "type_definition()")
  mapluafn("n", "<F5>", "signature_help()")
  mapluafn("n", "<F12>", "formatting()")
  mapluafn("n", "K", "hover()")
  mapluafn("n", "<Leader>imp", "implementation()")
  mapluafn("n", "<Leader>ref", "references()")
  mapluafn("n", "<Leader>rn", "rename()")
  mapluafn("n", "<Leader>ds", "document_symbol()")
  mapluafn("n", "<Leader>ws", "workspace_symbol()")
  mapluafn("n","<Leader>ac",'code_action()')
  vim.api.nvim_command("autocmd CursorHold * lua vim.lsp.util.show_line_diagnostics()")
  vim.api.nvim_command("autocmd CursorMoved * lua vim.lsp.util.buf_clear_references()")

  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gn', ':NextDiagnosticCycle<CR>', opts)
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gp', ':PrevDiagnosticCycle<CR>', opts)
end

-- override default config
nvim_lsp.util.default_config = vim.tbl_extend(
  "force",
  nvim_lsp.util.default_config,
  {
    log_level = vim.lsp.protocol.MessageType.Log;
    message_level = vim.lsp.protocol.MessageType.Log;
    on_attach = on_attach;
  }
)
nvim_lsp.pyls.setup{
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
nvim_lsp.clangd.setup{
  default_config = {
    cmd = { vim.fn.exepath('clangd'), '--clang-tidy', '--suggest-missing-includes' };
    filetypes = { "c", "cpp", "objc", "objcpp" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(c_cpp_root, general_root))
      or vim.fn.getcwd()
    end;
  };
}
nvim_lsp.tsserver.setup{
  default_config = {
    cmd = { vim.fn.exepath('typescript-language-server'), '--stdio', '--tsserver-log-file', '/tmp/ts.log' };
    filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(ts_js_root, general_root))
      or vim.fn.getcwd()
    end;
  };
}
nvim_lsp.html.setup{
  default_config = {
    filetypes = { "html" };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or vim.fn.getcwd()
    end;
  };
}
nvim_lsp.cssls.setup{
  default_config = {
    filetypes = {"css", "scss", "sass", "less"};
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or vim.fn.getcwd()
    end;
  };
}

nvim_lsp.gopls.setup{
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
nvim_lsp.sourcekit.setup{
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
