local lspconfig = require 'lspconfig'
local coq = require "coq"
local util = require 'lspconfig/util'
local sign_def = vim.fn.sign_define
local buf_keymap = require 'utils'.buf_keymap
local merge_tables = require 'utils'.merge_tables
local buf_opt = require 'utils'.buf_opt

vim.lsp.set_log_level("error")

general_root = {".root", ".project.*", ".git/", ".gitignore", "README.md"}
py_root = {'venv/', 'requirements.txt', 'setup.py', 'pyproject.toml', 'setup.cfg'}
ts_js_root = {'jsconfig.json', 'tsconfig.json', 'package.json'}
c_cpp_root = {'compile_commands.json', 'build/', 'compile_flags.txt', '.clangd'}
go_root = {'go.sum', 'go.mod'}
swift_root = {'Package.swift'}

-- buffer setup
local custom_on_attach = function(client, bufnr)
  buf_opt(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
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
  buf_keymap(bufnr, "n", "gn", [[<cmd>lua vim.diagnostic.goto_next { float = true }<CR>]])
  buf_keymap(bufnr, "n", "gp", [[<cmd>lua vim.diagnostic.goto_prev { float = true }<CR>]])
  buf_keymap(bufnr, "n", "<Space>ld", [[<cmd>lua vim.diagnostic.open_float(0, {scope="line"})<CR>]])
  buf_keymap(bufnr, "n", "<Space>ll", [[<cmd>lua vim.diagnostic.setloclist()<CR>]])
end

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
  }
)
vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  underline = false,
  update_in_insert = false,
  severity_sort = false,
})

local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

lspconfig.pyright.setup{
  coq.lsp_ensure_capabilities({
    default_config = {
      cmd = { vim.fn.exepath("pyright-langserver"), "--stdio" };
      filetypes = { "python" };
      root_dir = function(fname)
        return util.find_git_ancestor(fname) or util.root_pattern(merge_tables(py_root, general_root))
          or vim.fn.getcwd()
      end;
    };
  })
}
lspconfig.clangd.setup{
  coq.lsp_ensure_capabilities({
    default_config = {
      cmd = { vim.fn.exepath('clangd'), '--clang-tidy', '--suggest-missing-includes' };
      filetypes = { "c", "cpp", "objc", "objcpp" };
      root_dir = function(fname)
        return util.find_git_ancestor(fname) or util.root_pattern(merge_tables(c_cpp_root, general_root))
          or vim.fn.getcwd()
      end;
    };
  })
}
lspconfig.tsserver.setup{
  coq.lsp_ensure_capabilities({
    default_config = {
      cmd = { vim.fn.exepath('typescript-language-server'), '--stdio', '--tsserver-log-file', '/tmp/ts.log' };
      filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" };
      root_dir = function(fname)
        return util.find_git_ancestor(fname) or util.root_pattern(merge_tables(ts_js_root, general_root))
          or vim.fn.getcwd()
      end;
    };
  })
}
lspconfig.html.setup{
  coq.lsp_ensure_capabilities({
    default_config = {
      cmd = { vim.fn.exepath('html-languageserver'), '--stdio' };
      filetypes = { "html" };
      root_dir = function(fname)
        return util.find_git_ancestor(fname) or vim.fn.getcwd()
      end;
    };
  })
}
lspconfig.cssls.setup{
  coq.lsp_ensure_capabilities({
    default_config = {
      filetypes = {"css", "scss", "sass", "less"};
      root_dir = function(fname)
        return util.find_git_ancestor(fname) or vim.fn.getcwd()
      end;
    };
  })
}

lspconfig.gopls.setup{
  coq.lsp_ensure_capabilities({
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
  })
}
lspconfig.sourcekit.setup{
  coq.lsp_ensure_capabilities({
    cmd = { vim.fn.exepath('sourcekit-lsp') };
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
  })
}
