local status_ok, indent_blankline = pcall(require, "indent_blankline")
if not status_ok then
  return
end

indent_blankline.setup {
  char = "¦",
  use_treesitter = true,
  show_first_indent_level = false,
  buftype_exclude = {
    "terminal",
  },
  filetype_exclude = {
    "NvimTree",
    "git",
    "gitcommit",
    "help",
    "lspinfo",
    "man",
    "markdown",
    "packer",
    "text",
    "txt",
    "log"
  },
}
