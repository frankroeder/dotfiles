local gh = require("pack_helpers").gh
local settings = require "settings"

vim.pack.add({
  gh("nvim-tree/nvim-web-devicons"),
  gh("nvim-lualine/lualine.nvim"),
})

local compile_status = function()
  local vimtex = vim.b.vimtex
  if not vimtex or not vimtex.compiler then
    return ""
  end
  local compiler_status = vimtex.compiler.status
  if compiler_status == -1 or compiler_status == 0 then
    return ""
  end
  if vim.b.vimtex["compiler"]["continuous"] == 1 then
    if compiler_status == 1 then
      return "{⋯}"
    elseif compiler_status == 2 then
      return "{✓}"
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

local function parrot_status()
  local ok, parrot_config = pcall(require, "parrot.config")
  if not ok or type(parrot_config.get_status_info) ~= "function" then
    return ""
  end

  local status_info = parrot_config.get_status_info()
  if
    not status_info
    or not status_info.prov
    or not status_info.model
    or (status_info.is_chat and not status_info.prov.chat)
    or (not status_info.is_chat and not status_info.prov.command)
  then
    return ""
  end

  local status = status_info.is_chat and status_info.prov.chat.name or status_info.prov.command.name
  return string.format("🦜%s(%s)", status, status_info.model)
end

require("lualine").setup({
  options = {
    globalstatus = true,
    theme = settings.theme,
    disabled_filetypes = { "help", "Outline" },
  },
  sections = {
    lualine_c = { "filename", spell, parrot_status },
    lualine_x = {
      vimtex_compile_status,
      "filetype",
    },
  },
  extensions = { "fzf", "oil", "mason", "man" },
})
