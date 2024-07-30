return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    indent = { char = "¦" },
    scope = {
      enabled = false,
      show_start = false,
      show_end = false,
    },
    exclude = {
      filetypes = {
        "neo-tree",
        "lazy",
        "text",
        "txt",
        "log",
      },
    },
  },
}
