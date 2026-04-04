local gh = require("pack_helpers").gh

vim.pack.add({
  gh("nvim-lua/plenary.nvim"),
  gh("lewis6991/gitsigns.nvim"),
})

require("gitsigns").setup({
  signs = {
    add = { text = "+" },
    change = { text = "~" },
    delete = { text = "_" },
    topdelete = { text = "‾" },
    changedelete = { text = "~" },
    untracked = { text = "┆" },
  },
  on_attach = function(bufnr)
    local gs = require "gitsigns"

    local function map(mode, lhs, rhs, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, lhs, rhs, opts)
    end

    map("n", "<Leader>gnh", function()
      if vim.wo.diff then
        return "<Leader>gph"
      end
      vim.schedule(function()
        gs.next_hunk()
      end)
      return "<Ignore>"
    end, { expr = true })

    map("n", "<Leader>gph", function()
      if vim.wo.diff then
        return "<Leader>gnh"
      end
      vim.schedule(function()
        gs.prev_hunk()
      end)
      return "<Ignore>"
    end, { expr = true })

    map("n", "<Leader>gsh", gs.stage_hunk)
    map("n", "<Leader>grh", gs.reset_hunk)
    map("v", "<Leader>gsh", function()
      gs.stage_hunk({ vim.fn.line ".", vim.fn.line "v" })
    end)
    map("v", "<Leader>grh", function()
      gs.reset_hunk({ vim.fn.line ".", vim.fn.line "v" })
    end)

    map("n", "<Leader>gsb", gs.stage_buffer)
    map("n", "<Leader>guh", gs.undo_stage_hunk)
    map("n", "<Leader>grb", gs.reset_buffer)
    map("n", "<Leader>gb", function()
      gs.blame_line({ full = true })
    end)

    map("n", "<Leader>gp", gs.preview_hunk)
    map("n", "<Leader>gd", gs.diffthis)
    map("n", "<Leader>gtd", gs.toggle_deleted)
    map("n", "<Leader>gtb", gs.toggle_current_line_blame)
  end,
})
