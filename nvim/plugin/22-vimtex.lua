local gh = require("pack_helpers").gh
local utils = require "utils"

vim.pack.add({
  gh("lervag/vim-latex"),
})

local function callback(msg)
  local match = vim.fn.matchlist(msg, [[\vRun number (\d+) of rule ''(.*)'']])
  if not vim.tbl_isempty(match) then
    vim.cmd(("echomsg '%s (%s)'"):format(match[3], match[2]))
  end
end

vim.g.vimtex_syntax_conceal = {
  accents = 1,
  ligatures = 1,
  cites = 1,
  fancy = 1,
  spacing = 1,
  greek = 1,
  math_bounds = 1,
  math_delimiters = 1,
  math_fracs = 1,
  math_super_sub = 0,
  math_symbols = 1,
  sections = 1,
  styles = 1,
}

vim.g.vimtex_complete_enabled = 1
vim.g.vimtex_complete_close_braces = 1
vim.g.vimtex_fold_enabled = 0
vim.g.vimtex_format_enabled = 1
vim.g.vimtex_quickfix_mode = 2
vim.g.vimtex_quickfix_autoclose_after_keystrokes = 0
vim.g.vimtex_quickfix_open_on_warning = 0
vim.g.vimtex_view_automatic = 1
if utils.is_asahi_linux() then
  if vim.fn.executable 'okular' then
    vim.g.vimtex_view_general_viewer = 'okular'
    vim.g.vimtex_view_general_options = [[--unique file:@pdf\#src:@line@tex]]
  else
    print("No viewer for vimtex found.")
  end
else
  vim.g.vimtex_view_method = "sioyek"
  vim.g.vimtex_view_sioyek_options = "--reuse-window --execute-command toggle_synctex"
  vim.g.vimtex_general_viewer = "sioyek"
  vim.g.vimtex_view_general_options = "-r @line @pdf @tex"
end
vim.g.vimtex_parser_bib_backend = "lua"
vim.g.vimtex_log_ignore = {
  "Underfull",
  "Overfull",
  "specifier changed to",
  "Token not allowed in a PDF string",
}
vim.g.vimtex_compiler_latexmk = {
  backend = "nvim",
  background = 1,
  out_dir = "build/",
  callback = 1,
  continuous = 1,
  executable = "latexmk",
  hooks = {
    callback,
  },
  options = {
    "-verbose",
    "-file-line-error",
    "-synctex=1",
    "-interaction=nonstopmode",
  },
}
vim.g.vimtex_complete_bib = {
  simple = 1,
  menu_fmt = '@key @author_short (@year), "@title"',
}
vim.g.vimtex_toc_config = {
  split_pos = "full",
  layer_status = {
    label = 0,
  },
}
vim.g.vimtex_delim_toggle_mod_list = {
  { [[\left]], [[\right]] },
  { [[\big]], [[\big]] },
}

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("vimtex_keymaps", { clear = true }),
  pattern = "tex",
  callback = function(ev)
    vim.wo.conceallevel = 1
    vim.keymap.set("n", "<Space>tt", "<Plug>(vimtex-toc-toggle)", { buffer = ev.buf })
    vim.keymap.set("n", "<Space>tv", "<Plug>(vimtex-view)", { buffer = ev.buf })
    vim.keymap.set("n", "<Space>tc", "<Plug>(vimtex-compile)", { buffer = ev.buf })
    vim.keymap.set("n", "<Space>ctl", function()
      vim.cmd [[call vimtex#fzf#run('ctl')]]
    end, { buffer = ev.buf, desc = "Search labels and todos" })
  end,
})
