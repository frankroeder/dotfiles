local general_root = require("plugins.lsp.util").general_root
local util = require "lspconfig/util"
local merge_tables = require("utils").merge_tables
local c_cpp_root = { "compile_commands.json", "build/", "compile_flags.txt", ".clangd" }

return {
  cmd = {
    vim.fn.exepath "clangd",
    "--clang-tidy",
    "--suggest-missing-includes",
  },
  filetypes = { "c", "cpp", "objc", "objcpp" },
  root_dir = function(fname)
    return util.root_pattern(unpack(merge_tables(c_cpp_root, general_root)))(fname)
      or util.find_git_ancestor(fname)
      or util.path.dirname(fname)
  end,
}
