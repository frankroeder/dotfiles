---@type vim.lsp.Config
return {
  cmd = {
    "clangd",
    "--clang-tidy",
    "--suggest-missing-includes",
  },
  filetypes = { "c", "cpp", "objc", "objcpp" },
  root_markers = {
    "Makefile",
    "CMakefile.txt",
    "compile_commands.json",
    "build/",
    "compile_flags.txt",
    ".clangd",
  },
  single_file_support = true,
  capabilities = {
    textDocument = { completion = { editsNearCursor = true } },
    offsetEncoding = { "utf-8", "utf-16" },
  },
}
