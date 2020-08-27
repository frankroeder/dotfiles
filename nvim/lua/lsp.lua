local nvim_lsp = require'nvim_lsp'
local util = require 'nvim_lsp/util'

vim.lsp.set_log_level("error")
vim.lsp.callbacks["textDocument/publishDiagnostics"] = function() end

function table.merge(t1, t2)
  for k,v in ipairs(t2) do
    table.insert(t1, v)
  end
  return t1
end

--TODO: Fix root_dir
general_root = {".root", ".project.*", ".git/", ".gitignore", "README.md"}
py_root = {'venv/', 'requirements.txt', 'setup.py'}
ts_js_root = {'jsconfig.json', 'tsconfig.json', 'package.json'}
c_cpp_root = {'compile_commands.json', 'build/'}
go_root = {'go.sum', 'go.mod'}

nvim_lsp.util.default_config = vim.tbl_extend(
  "force",
  nvim_lsp.util.default_config,
  { log_level = vim.lsp.protocol.MessageType.Warning }
)

nvim_lsp.pyls.setup{
  enable = true;
  default_config = {
    cmd = { vim.fn.exepath('pyls'), '--log-file' , '/tmp/pyls.log' };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(py_root, general_root))
        or util.path.dirname(fname) or vim.fn.getcwd()
    end;
  };
  settings = {
    pyls = {
      plugins = {
        pyflakes = { enabled = true; };
        pydocstyle = { enabled = false; };
        pylint = { enabled = false; };
        mccabe = { enabled = false; };
        rope_completion = { enabled = true; };
      }
    }
  };
}
nvim_lsp.clangd.setup{
  default_config = {
    cmd = { 'clangd', '--clang-tidy', '--suggest-missing-includes' };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(c_cpp_root, general_root))
        or util.path.dirname(fname) or vim.fn.getcwd()
    end;
  };
}
nvim_lsp.tsserver.setup{
  default_config = {
    cmd = { 'typescript-language-server', '--stdio', '--tsserver-log-file', '/tmp/ts.log' };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(ts_js_root, general_root))
        or util.path.dirname(fname) or vim.fn.getcwd()
    end;
  };
}
nvim_lsp.html.setup{
  default_config = {
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.path.dirname(fname) or vim.fn.getcwd()
    end;
  };
}
nvim_lsp.cssls.setup{
  default_config = {
    filetypes = {"css", "scss", "sass", "less"};
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.path.dirname(fname) or vim.fn.getcwd()
    end;
  };
}

nvim_lsp.gopls.setup{
  default_config = {
    cmd = { 'gopls', '-logfile', '/tmp/gopls.log' };
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.root_pattern(table.merge(go_root, general_root))
        or util.path.dirname(fname) or vim.fn.getcwd()
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
  default_config = {
    root_dir = function(fname)
      return util.find_git_ancestor(fname) or util.path.dirname(fname) or vim.fn.getcwd()
    end;
  };
}
