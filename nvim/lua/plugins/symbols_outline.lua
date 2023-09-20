local M = { "simrat39/symbols-outline.nvim" }

function M.config()
  local status_ok, symbols_outline = pcall(require, "symbols-outline")
  if not status_ok then
    return
  end

  symbols_outline.setup {
    highlight_hovered_item = false,
    show_guides = true,
    auto_preview = false,
    position = "right",
    relative_width = true,
    width = 25,
    auto_close = false,
    autofold_depth = 0,
    auto_unfold_hover = false,
    show_numbers = false,
    show_relative_numbers = false,
    show_symbol_details = true,
    preview_bg_highlight = "FocusedSymbol",
  }

  vim.keymap.set("n", "<Leader>s", ":SymbolsOutline<CR>")
end

return M
