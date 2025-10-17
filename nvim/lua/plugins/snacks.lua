return {
  "folke/snacks.nvim",
  priority = 1000,
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
    styles = {
      notification = {
        wo = { wrap = true },
      },
    },
		-- TODO
    -- statuscolumn = { enabled = true },
  },
  keys = {
    {
      "<C-C>",
      function()
        Snacks.bufdelete()
      end,
      desc = "Delete Buffer",
    },
    {
      "<leader>.",
      function()
        Snacks.scratch()
      end,
      desc = "Toggle Scratch Buffer",
    },
    {
      "<Leader>..",
      function()
        Snacks.scratch.select()
      end,
      desc = "Select Scratch Buffer",
    },
    {
      "<Leader>ä",
      function()
        Snacks.terminal()
      end,
      desc = "Toggle Terminal",
    },
    {
      "<leader>e",
      function()
        Snacks.explorer()
      end,
      desc = "File Explorer",
    },
  },
  init = function()
    require "snacks"
    vim.api.nvim_create_user_command("GitBrowse", function()
      Snacks.gitbrowse()
    end, {})
    vim.api.nvim_create_user_command("Notifications", function()
      Snacks.notifier.show_history {}
    end, {})
  end,
}
