local keymap  = require 'utils'.keymap

vim.g.symbols_outline = {
    highlight_hovered_item = false,
    show_guides = true,
    auto_preview = false,
    position = 'right',
    relative_width = true,
    width = 25,
    auto_close = false,
    show_numbers = false,
    show_relative_numbers = true,
    show_symbol_details = true,
    preview_bg_highlight = 'FocusedSymbol'
}

keymap("n", "<Leader>s", [[:SymbolsOutline<CR>]])
