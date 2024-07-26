local M = {}

-- refer to the themes settings file for different styles
M.theme = "catppuccin"
-- treesitter parsers to be installed
-- one of "all", "maintained" (parsers with maintainers), or a list of languages
M.treesitter_ensure_installed = {
  "bash",
  "bibtex",
  "c",
  "cmake",
  -- "comment", -- for tags like TODO, FIXME, NOTE, BUG, HACK, XXX -- see #5057
  "cpp",
  "css",
  "csv",
  "dockerfile",
  "gitignore",
  "go",
  "gomod",
  "html",
  "javascript",
  "json",
  "latex",
  "lua",
  "make",
  "markdown",
  "markdown_inline",
  "python",
  "r",
  "swift",
  "svelte",
  "toml",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

return M
