---@type vim.lsp.Config
return {
  cmd = { "jedi-language-server" },
  filetypes = { "python" },
  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "pyrightconfig.json",
  },
  settings = {},
  init_options = {
    diagnostics = {
      enable = false,
      didOpen = true,
      didChange = true,
      didSave = true,
    },
    hover = {
      enable = true,
    },
    markupKindPreferred = "markdown",
  },
}
