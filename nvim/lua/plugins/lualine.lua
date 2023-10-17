local settings = require "settings"

local M = {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons", lazy = true },
}

function M.config()
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

  local vimtex_compile_status = {
    compile_status,
    cond = function()
      return vim.bo.filetype == "tex"
    end,
  }

  local lazy_plugin_status = {
    require("lazy.status").updates,
    cond = require("lazy.status").has_updates,
    color = { fg = "#ff9e64" },
  }

  require("lualine").setup {
    options = {
      globalstatus = true,
      theme = settings.theme,
      disabled_filetypes = { "help", "Outline" },
    },
    sections = {
      lualine_x = {
        "aerial",
        vimtex_compile_status,
        "filetype",
        lazy_plugin_status,
      },
    },
    extensions = { "neo-tree", "fzf", "lazy", "symbols-outline" },
  }
end

return M
