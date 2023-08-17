local M = {
  "romgrk/barbar.nvim",
  event = "VeryLazy",
  dependencies = {
    "lewis6991/gitsigns.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  version = "^1.6.5",
  init = function()
    vim.g.barbar_auto_setup = false
  end,
}

function M.config()
  -- Set barbar's options
  require("barbar").setup {
    -- Enable/disable animations
    animation = false,
    -- Enable/disable auto-hiding the tab bar when there is a single buffer
    auto_hide = false,
    -- Enable/disable current/total tabpages indicator (top right corner)
    tabpages = true,
    -- Enables/disable clickable tabs
    --  - left-click: go to buffer
    --  - middle-click: delete buffer
    clickable = true,
    hide = { extensions = false, inactive = false },
    highlight_visible = true,
    -- Icon settings
    icons = {
      buffer_index = false,
      buffer_number = false,
      button = "",
      diagnostics = { { enabled = false }, { enabled = false } },
      filetype = { enabled = false },
      separator = { left = "▎" },
      alternate = { filetype = { enabled = false } },
      current = { buffer_index = false },
      inactive = { button = "" },
      visible = { modified = { buffer_number = false } },
    },
    -- If true, new buffers will be inserted at the end of the list.
    -- Default is to insert after current buffer.
    insert_at_end = true,

    -- Sets the maximum padding width with which to surround each tab
    maximum_padding = 1,

    -- Sets the maximum buffer name length.
    maximum_length = 20,
  }

  vim.keymap.set("n", "<C-K>", ":BufferNext<CR>")
  vim.keymap.set("n", "<C-J>", ":BufferPrevious<CR>")
  vim.keymap.set("n", "<C-C>", ":BufferClose<CR>")
end

return M
