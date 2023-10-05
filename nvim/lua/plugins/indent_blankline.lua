local M = {
  "lukas-reineke/indent-blankline.nvim",
  event = { "BufReadPre", "BufNewFile" },
}

function M.config()
  local status_ok, ibl = pcall(require, "ibl")
  if not status_ok then
    return
  end

  ibl.setup {
    indent = { char = "¦" },
    scope = { enabled = false },
    exclude = {
      filetypes = {
        "neo-tree",
        "git",
        "gitcommit",
        "help",
        "lspinfo",
        "man",
        "markdown",
        "lazy",
        "text",
        "txt",
        "log",
      },
      buftypes = {
        "terminal",
        "nofile",
      },
    },
  }
end

return M
