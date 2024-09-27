return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  lazy = false,
  cmd = "Oil",
  opts = {
    default_file_explorer = true,
    delete_to_trash = true,
    watch_for_changes = false,
    view_options = {
      show_hidden = true,
    },
  },
  keys = {
    {
      "<Leader>o",
      function()
        require("oil").toggle_float()
      end,
      { desc = "Oil Toggle" },
    },
  },
}
