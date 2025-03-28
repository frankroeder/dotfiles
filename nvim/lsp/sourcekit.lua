---@type vim.lsp.Config
return {
  cmd = { "sourcekit-lsp" },
  filetypes = { "swift", "c", "cpp", "objective-c", "objective-cpp", "objc", "objcpp" },
  root_markers = {
    "buildServer.json",
    "*.xcodeproj",
    "*.xcworkspace",
    "compile_commands.json",
    "Package.swift",
  },
  settings = {
    serverArguments = { "--log-level", "debug" },
    trace = { server = "messages" },
  },
  capabilities = {
    textDocument = {
      diagnostic = {
        dynamicRegistration = true,
        relatedDocumentSupport = true,
      },
    },
  },
}
