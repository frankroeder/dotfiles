---@type vim.lsp.Config
return {
  cmd = {
    "clangd",
    "--clang-tidy",
  },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
  root_markers = {
    "Makefile",
    "CMakefile.txt",
    "compile_commands.json",
    "build/",
    "compile_flags.txt",
    ".clangd",
    ".clang-tidy",
    ".clang-format",
    "compile_flags.txt",
    "configure.ac",
  },
  single_file_support = true,
  capabilities = {
    textDocument = { completion = { editsNearCursor = true } },
    offsetEncoding = { "utf-8", "utf-16" },
  },
}
