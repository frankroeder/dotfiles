local M = {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "nvim-treesitter/playground" },
}

function M.config()
  local status_ok, nvim_treesitter = pcall(require, "nvim-treesitter.configs")
  if not status_ok then
    return
  end
  local settings = require "settings"

  nvim_treesitter.setup {
    ensure_installed = settings.treesitter_ensure_installed,
    ignore_install = { "latex", "bibtex" },
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
      disable = { "latex", "bibtex", "markdown", "help" },
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
  }
end

return M
