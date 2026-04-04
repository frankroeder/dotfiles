local gh = require("pack_helpers").gh

vim.pack.add({
  gh("stevearc/oil.nvim"),
})

function _G.get_oil_winbar()
  local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid)
  local dir = require("oil").get_current_dir(bufnr)
  if dir then
    return vim.fn.fnamemodify(dir, ":~")
  end
  return vim.api.nvim_buf_get_name(0)
end

OilDetails = false

require("oil").setup({
  default_file_explorer = true,
  delete_to_trash = true,
  watch_for_changes = true,
  view_options = {
    show_hidden = true,
  },
  win_options = {
    winbar = "%!v:lua.get_oil_winbar()",
  },
})

vim.keymap.set("n", "<Leader>o", function()
  require("oil").toggle_float()
end, { desc = "Oil Toggle" })

vim.keymap.set("n", "gd", function()
  OilDetails = not OilDetails
  if OilDetails then
    require("oil").set_columns({ "icon", "permissions", "size", "mtime" })
  else
    require("oil").set_columns({ "icon" })
  end
end, { desc = "Toggle file detail view" })
