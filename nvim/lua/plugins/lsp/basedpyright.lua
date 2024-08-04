return {
  settings = {
    basedpyright = {
      disableOrganizeImports = true,
      analysis = {
        typeCheckingMode = "standard", -- off, basic, standard, strict, all
        autoImportCompletions = true,
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticsMode = "openFilesOnly", -- workspace, openFilesOnly
        diagnosticSeverityOverrides = {
          reportUnusedImports = false,
          reportUnusedVariable = false,
        },
      },
    },
  },
}
