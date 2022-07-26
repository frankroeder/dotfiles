require("indent_blankline").setup {
  char = "¦",
  buftype_exclude = {"terminal"},
  filetype_exclude = {
  	"man",
  	"help",
  	"markdown",
  	"NvimTree",
  	"packer"
  },
  use_treesitter = true,
  show_first_indent_level = false,
}
