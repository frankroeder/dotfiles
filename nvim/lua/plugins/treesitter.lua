return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
  keys = {
    { "<C-Space>", desc = "Increment Selection" },
    { "<BS>", desc = "Decrement Selection", mode = "x" },
  },
  opts = {
    ensure_installed = require("settings").treesitter_ensure_installed,
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
      disable = {
        "latex",
        -- "python" -- semantic highlighting via lsp
      },
    },
    indent = {
      enable = true,
      -- disable = { "python" }, -- still unstable
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        -- mappings for incremental selection (visual mappings)
        init_selection = "<C-Space>", -- maps in normal mode to init the node/scope selection
        node_incremental = "<C-Space>", -- increment to the upper named parent
        scope_incremental = false, -- increment to the upper scope (as defined in locals.scm)
        node_decremental = "<BS>", -- decrement to the previous node
      },
    },
  },
}
