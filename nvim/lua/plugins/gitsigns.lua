local is_git_repo = require("utils").is_git_repo

local M = {
  "lewis6991/gitsigns.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = { "BufReadPre", "BufNewFile" },
  cond = function()
    return is_git_repo()
  end,
}

function M.config()
  local gs = require "gitsigns"

  gs.setup {
    signs = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
      untracked = { text = "┆" },
    },
    on_attach = function(bufnr)
      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      -- Navigation
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

      -- Actions
      map("n", "<Leader>gsh", gs.stage_hunk)
      map("n", "<Leader>grh", gs.reset_hunk)
      map("v", "<Leader>gsh", function()
        gs.stage_hunk { vim.fn.line ".", vim.fn.line "v" }
      end)
      map("v", "<Leader>grh", function()
        gs.reset_hunk { vim.fn.line ".", vim.fn.line "v" }
      end)

      map("n", "<Leader>gsb", gs.stage_buffer)
      map("n", "<Leader>guh", gs.undo_stage_hunk)
      map("n", "<Leader>grb", gs.reset_buffer)
      map("n", "<Leader>gb", function()
        gs.blame_line { full = true }
      end)

      map("n", "<Leader>gp", gs.preview_hunk)
      map("n", "<Leader>gd", gs.diffthis)
      map("n", "<Leader>gtd", gs.toggle_deleted)
      map("n", "<Leader>gtb", gs.toggle_current_line_blame)
    end,
  }
end

return M
