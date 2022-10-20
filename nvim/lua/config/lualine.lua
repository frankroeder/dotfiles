local compile_status = function()
  local vimtex = vim.b.vimtex
  local compiler_status = vimtex.compiler.status
  -- not started or stopped
  if compiler_status == -1 or compiler_status == 0 then
    return ""
  end
  if vim.b.vimtex["compiler"]["continuous"] == 1 then
    -- running
    if compiler_status == 1 then
      return "{⋯}"
    -- success
    elseif compiler_status == 2 then
      return "{✓}"
    -- failed
    elseif compiler_status == 3 then
      return "{✗}"
    end
  end
  return ""
end

require("lualine").setup {
  options = {
    globalstatus = true,
    theme = "catppuccin",
    disabled_filetypes = { "help", "Outline" },
  },
  sections = {
    lualine_x = {
      {
        compile_status,
        cond = function()
          return vim.bo.filetype == "tex"
        end,
      },
      "filetype",
    },
  },
  extensions = { "nvim-tree", "fzf" },
}
