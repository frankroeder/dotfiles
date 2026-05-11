local M = {}

local mode_names = {
  n = "NORMAL",
  i = "INSERT",
  v = "VISUAL",
  V = "V-LINE",
  ["\22"] = "V-BLOCK",
  c = "COMMAND",
  R = "REPLACE",
  t = "TERMINAL",
}

local skip = {
  help = true,
  Outline = true,
}

local sl = function(group)
  return "%#" .. group .. "#"
end

local winid = function()
  return vim.g.statusline_winid or 0
end

local bufnr = function()
  return vim.api.nvim_win_get_buf(winid())
end

local hl = function(group)
  return vim.api.nvim_get_hl(0, { name = group, link = false, create = false })
end

local redraw = function()
  vim.api.nvim__redraw({ statusline = true })
end

local set_hl = function()
  vim.api.nvim_set_hl(0, "StatusLineBold", { bold = true })
  vim.api.nvim_set_hl(0, "StatusLineDim", { fg = hl("LineNr").fg })
  vim.api.nvim_set_hl(0, "StatusLineModified", { fg = hl("String").fg, bold = true })
  vim.api.nvim_set_hl(0, "StatusLineFiletype", {
    fg = vim.o.background == "light" and 0x000000 or 0xffffff,
  })
end

local devicon = function(name, ext, ft)
  local ok, icons = pcall(require, "nvim-web-devicons")
  if not ok then
    return
  end

  local icon, group = icons.get_icon(name, ext)
  if icon then
    return icon, group
  end

  return icons.get_icon_by_filetype(ft, { default = true })
end

local file_info = function()
  local buf = bufnr()
  local path = vim.api.nvim_buf_get_name(buf)
  local ft = vim.bo[buf].filetype
  local bt = vim.bo[buf].buftype

  if skip[ft] or (ft == "" and path == "") then
    return
  end

  local name = vim.fn.fnamemodify(path, ":t")
  local display = name ~= "" and name or path
  local icon, group = devicon(name, vim.fn.fnamemodify(path, ":e"), ft)

  if bt == "terminal" then
    if display:match("^zsh") then
      icon, group = "", "Special"
    elseif display:match("^claude") or display:match("^opencode") or display:match("^copilot") then
      icon, group = "󰚩", "Special"
    elseif display:match("^python ?") then
      icon, group = devicon("", "", "python")
    end
  end

  return { buf = buf, ft = ft, bt = bt, display = display, icon = icon, group = group or "StatusLine" }
end

local mode = function()
  local id = vim.api.nvim_get_mode().mode:sub(1, 1)
  return sl("StatusLineBold") .. (mode_names[id] or id)
end

local git = function()
  local head = vim.b.gitsigns_head
  if not head or head == "" then
    return
  end

  return " " .. head
end

local diagnostics = function()
  return vim.diagnostic.status(bufnr()):gsub("%w+:", " %0", 1):gsub("(:%d+)%%", "%1 %%")
end

local filename = function(info)
  if not info then
    return
  end

  local modified = vim.bo[info.buf].modified and sl("StatusLineModified") .. "[+]" or ""
  if not info.icon then
    return sl("StatusLineBold") .. info.display .. modified
  end

  return sl(info.group) .. info.icon .. " " .. sl("StatusLineBold") .. info.display .. modified
end

local spell = function()
  if not vim.wo[winid()].spell then
    return
  end

  local lang = vim.split(vim.bo[bufnr()].spelllang, ",", { plain = true })[1]
  return lang ~= "" and sl("StatusLineDim") .. ("[%s]"):format(lang) or nil
end

local parrot = function()
  local ok, config = pcall(require, "parrot.config")
  if not ok or type(config.get_status_info) ~= "function" then
    return
  end

  local info = config.get_status_info()
  local provider = info and info.prov and (info.is_chat and info.prov.chat or info.prov.command)
  return provider and info.model and sl("StatusLineDim") .. ("🦜%s(%s)"):format(provider.name, info.model) or nil
end

local vimtex = function(info)
  if not info or info.ft ~= "tex" then
    return
  end

  local state = vim.b[info.buf].vimtex
  if not state or not state.compiler or state.compiler.continuous ~= 1 then
    return
  end

  local status = ({ [1] = "{⋯}", [2] = "{✓}", [3] = "{✗}" })[state.compiler.status]
  return status and sl("StatusLineDim") .. status or nil
end

local filetype = function(info)
  if not info then
    return
  end

  local label = info.ft ~= "" and info.ft or info.bt
  if label == "" then
    return
  end

  if not info.icon then
    return sl("StatusLineFiletype") .. label
  end

  return sl(info.group) .. info.icon .. " " .. sl("StatusLineFiletype") .. label
end

local position = function()
  return sl("StatusLineDim") .. ("%d:%d"):format(vim.fn.line("."), vim.fn.virtcol("."))
end

set_hl()

local group = vim.api.nvim_create_augroup("jscott/statusline", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })
vim.api.nvim_create_autocmd("OptionSet", { group = group, pattern = "background", callback = set_hl })
vim.api.nvim_create_autocmd("User", { group = group, pattern = "GitSignsUpdate", callback = redraw })

vim.o.statusline = "%!v:lua.require'statusline'.render()"

function M.render()
  if skip[vim.bo[bufnr()].filetype] then
    return ""
  end

  local info = file_info()
  if winid() ~= vim.fn.win_getid() then
    return info and " " .. filename(info) or ""
  end

  return table.concat(vim.tbl_filter(function(part)
    return part and part ~= ""
  end, {
    mode(),
    filename(info),
    spell(),
    parrot(),
    "%=",
    diagnostics(),
    git(),
    vimtex(info),
    filetype(info),
    position(),
  }), sl("StatusLine") .. " ")
end

return M
