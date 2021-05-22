require'nvim-treesitter.configs'.setup {
  ensure_installed = {
    "bash", "bibtex", "c", "cpp", "css", "dockerfile", "go", "gomod", "html",
    "javascript", "json", "latex", "lua", "python", "r", "swift", "toml",
    "typescript", "yaml"
  },
  highlight = {
    enable = true,
    disable = { "tex", "bibtex", "markdown" }
  },
  indent = {
    enable = true
  },
  rainbow = {
    enable = true
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gnn",
      node_incremental = "grn",
      scope_incremental = "grc",
      node_decremental = "grm",
    }
  }
}
