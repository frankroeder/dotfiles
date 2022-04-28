require'nvim-treesitter.configs'.setup {
  ensure_installed = {
    "bash", "c", "cmake", "cpp", "css", "dockerfile", "go", "gomod", "html",
    "javascript", "json", "latex", "lua", "make", "python", "r", "swift", "toml",
    "typescript", "vim", "yaml"
  },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
    disable = { "bibtex", "markdown" }
  },
  indent = {
    enable = true,
    disable = {"python"} -- still unstable
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      -- mappings for incremental selection (visual mappings)
      init_selection = "gnn", -- maps in normal mode to init the node/scope selection
      node_incremental = "grn", -- increment to the upper named parent
      scope_incremental = "grc", -- increment to the upper scope (as defined in locals.scm)
      node_decremental = "grm" -- decrement to the previous node
    }
  },
  -- nvim-ts-rainbow
  rainbow = {
    enable = true,
    -- highlight non-bracket delimiters like html tags, boolean or table
    extended_mode = true,
    max_file_lines = 2500
  }
}
