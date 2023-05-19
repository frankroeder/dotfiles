local M = {
  "kylechui/nvim-surround",
  event = "BufReadPost",
}

function M.config()
  local status_ok, surround = pcall(require, "nvim-surround")
  if not status_ok then
    return
  end
  surround.setup()
end

return M
