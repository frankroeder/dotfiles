return {
  "folke/snacks.nvim",
  opts = {
    bigfile = { enabled = true },
    image = { enabled = true },
    gitbrowse = { enabled = true },
    -- statuscolumn = { enabled = true },
    --  indent = {
    --    enabled = true,
    --    char = "╎",
    -- only_current = true,
    --  },
  },
  -- keys = {
  --   {
  --     "gns",
  --     function()
  --       Snacks.words.jump(vim.v.count1)
  --     end,
  --     desc = "Next Reference",
  --     mode = { "n", "t" },
  --   },
  --   {
  --     "gps",
  --     function()
  --       Snacks.words.jump(-vim.v.count1)
  --     end,
  --     desc = "Prev Reference",
  --     mode = { "n", "t" },
  --   },
  -- },
  init = function()
    require "snacks"
    vim.api.nvim_create_user_command("GitBrowse", function()
      Snacks.gitbrowse()
    end, {})
  end,
}
