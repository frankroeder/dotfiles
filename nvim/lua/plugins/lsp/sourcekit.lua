local merge_tables = require("utils").merge_tables
local util = require "lspconfig/util"
local general_root = require("plugins.lsp.util").general_root
local swift_root = { "Package.swift" }

return {
  cmd = { "sourcekit-lsp" },
  filetypes = { "swift", "c", "cpp", "objective-c", "objective-cpp" },
  root_dir = function(fname)
    return util.root_pattern(unpack(merge_tables(swift_root, general_root)))(fname)
      or util.find_git_ancestor(fname)
      or util.path.dirname(fname)
  end,
  settings = {
    serverArguments = { "--log-level", "debug" },
    trace = { server = "messages" },
  },
}
