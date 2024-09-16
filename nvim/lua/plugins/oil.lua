return {
  "stevearc/oil.nvim",
  opts = {
    default_file_explorer = true,
    delete_to_trash = true,
    watch_for_changes = false,
    view_options = {
      show_hidden = true,
    },
  },
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "Oil",
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
