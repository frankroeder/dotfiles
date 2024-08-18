local settings = require "settings"

local M = {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons", lazy = true },
}

function M.opts()
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

  local function spell()
    if vim.opt_local.spell:get() then
      local lang = vim.opt_local.spelllang:get()[1]
      return ("[%s]"):format(lang)
    end
    return ""
  end

  local lazy_plugin_status = {
    require("lazy.status").updates,
    cond = require("lazy.status").has_updates,
    color = { fg = "#ff9e64" },
  }

  local function parrot_status()
    local status_info = require("parrot.config").get_status_info()
    local status = ""
    if status_info.is_chat then
      status = status_info.prov.chat.name
    else
      status = status_info.prov.command.name
    end
    return string.format("🦜%s(%s)", status, status_info.model)
  end

  local opts = {
    options = {
      globalstatus = true,
      theme = settings.theme,
      disabled_filetypes = { "help", "Outline" },
    },
    sections = {
      lualine_c = { "filename", spell, parrot_status },
      lualine_x = {
        "aerial",
        vimtex_compile_status,
        "filetype",
        lazy_plugin_status,
      },
    },
    extensions = { "neo-tree", "fzf", "lazy", "oil", "aerial", "mason", "man" },
  }
  return opts
end

return M
