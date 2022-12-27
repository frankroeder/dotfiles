local M = {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = "BufReadPost",
  dependencies = { "p00f/nvim-ts-rainbow", "nvim-treesitter/playground" },
}

function M.config()
  local status_ok, nvim_treesitter = pcall(require, "nvim-treesitter.configs")
  if not status_ok then
    return
  end
  local settings = require "settings"

  nvim_treesitter.setup {
    ensure_installed = settings.treesitter_ensure_installed,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
      disable = { "bibtex", "markdown", "help" },
    },
    indent = {
      enable = true,
      disable = { "python" }, -- still unstable
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        -- mappings for incremental selection (visual mappings)
        init_selection = "gnn", -- maps in normal mode to init the node/scope selection
        node_incremental = "grn", -- increment to the upper named parent
        scope_incremental = "grc", -- increment to the upper scope (as defined in locals.scm)
        node_decremental = "grm", -- decrement to the previous node
      },
    },
    -- nvim-ts-rainbow
    rainbow = {
      enable = true,
      -- highlight non-bracket delimiters like html tags, boolean or table
      extended_mode = true,
      max_file_lines = 2500,
    },
  }
end

return M
