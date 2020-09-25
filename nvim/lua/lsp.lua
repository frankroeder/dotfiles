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

local function mapluafn(mode, key, cmd)
  local value = '<cmd>lua '..cmd..'<CR>'
  vim.api.nvim_buf_set_keymap(0, mode, key, value, { silent= true; noremap= true })
end

-- buffer-local setup
local on_attach = function(client, bufnr)
  print("LSP started.");
  require'diagnostic'.on_attach(client)
  vim.api.nvim_buf_set_option(0, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
  mapluafn("n", "<F2>", "vim.lsp.buf.declaration()")
  mapluafn("n", "<F3>", "vim.lsp.buf.definition()")
  mapluafn("n", "<F4>", "vim.lsp.buf.type_definition()")
  mapluafn("n", "<F5>", "vim.lsp.buf.signature_help()")
  mapluafn("n", "<F12>", "vim.lsp.buf.formatting()")
  mapluafn("n", "K", "vim.lsp.buf.hover()")
  mapluafn("n", "gD", "vim.lsp.buf.implementation()")
  mapluafn("n", "gr", "vim.lsp.buf.references()")
  mapluafn("n", "<Leader>rn", "vim.lsp.buf.rename()")
  mapluafn("n", "gS", "vim.lsp.buf.document_symbol()")
  mapluafn("n", "gW", "vim.lsp.buf.workspace_symbol()")
  mapluafn("n",'<Leader>af','vim.lsp.buf.code_action()')
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
