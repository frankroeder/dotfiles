local M = {}

-- theme: nightfox, tokyonight, tundra; default is catppuccin
-- refer to the themes settings file for different styles
M.theme = "catppuccin"
-- treesitter parsers to be installed
-- one of "all", "maintained" (parsers with maintainers), or a list of languages
M.treesitter_ensure_installed = {
  "bash",
  "c",
  "cmake",
  "comment", -- for tags like TODO, FIXME, NOTE, BUG, HACK
  "cpp",
  "css",
  "dockerfile",
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
  "toml",
  "typescript",
  "vim",
  "yaml",
}

return M
