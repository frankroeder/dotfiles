local M = {}

-- refer to the themes settings file for different styles
M.theme = "catppuccin"
-- treesitter parsers to be installed
-- one of "all", "maintained" (parsers with maintainers), or a list of languages
M.treesitter_ensure_installed = {
  "bash",
  "c",
  "cmake",
  -- NOTE: this should be slowing down TS? --
  "comment", -- for tags like TODO, FIXME, NOTE, BUG, HACK, XXX
  "cpp",
  "css",
  "dockerfile",
  "gitcommit",
  "gitignore",
  "go",
  "gomod",
  "html",
  "javascript",
  "json",
  "latex",
  "lua",
  "make",
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
