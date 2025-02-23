return {
  "folke/snacks.nvim",
  opts = {
    bigfile = { enabled = true },
    gitbrowse = { enabled = true },
    image = {
      enabled = true,
      doc = {
        max_width = 60,
        max_height = 30,
      },
      img_dirs = { "figures" },
      math = {
        enabled = false,
      },
    },
    notifier = { enabled = true },
    rename = { enabled = true },
  },
  init = function()
    require "snacks"
    vim.api.nvim_create_user_command("GitBrowse", function()
      Snacks.gitbrowse()
    end, {})
  end,
}
