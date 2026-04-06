local gh = require("pack_helpers").gh

vim.pack.add({
  gh("folke/snacks.nvim"),
})

local snacks = require "snacks"

snacks.setup({
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
})

vim.api.nvim_create_user_command("GitBrowse", function()
  snacks.gitbrowse()
end, {})

vim.api.nvim_create_user_command("Notifications", function()
  snacks.notifier.show_history({})
end, {})

vim.keymap.set("n", "<C-C>", function()
  snacks.bufdelete()
end, { desc = "Delete Buffer" })

vim.keymap.set("n", "<leader>.", function()
  snacks.scratch()
end, { desc = "Toggle Scratch Buffer" })

vim.keymap.set("n", "<Leader>..", function()
  snacks.scratch.select()
end, { desc = "Select Scratch Buffer" })

vim.keymap.set("n", "<Leader>ä", function()
  snacks.terminal()
end, { desc = "Toggle Terminal" })

vim.keymap.set("n", "<leader>e", function()
  snacks.explorer()
end, { desc = "File Explorer" })
