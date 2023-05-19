local M = {
  "numToStr/Comment.nvim",
  event = "VeryLazy",
}

function M.config()
  local status_ok, comment = pcall(require, "Comment")
  if not status_ok then
    return
  end
  comment.setup()
end

return M
