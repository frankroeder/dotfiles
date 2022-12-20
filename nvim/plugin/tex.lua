vim.wo.conceallevel = 0
vim.g.tex_conceal = "abdmg"
vim.g.tex_flavor = "latex"
vim.g.vimtex_view_method = "sioyek"
vim.g.vimtex_view_general_options = "-r @line @pdf @tex"
vim.g.vimtex_quickfix_mode = 0
vim.g.vimtex_complete_close_braces = 1
vim.g.vimtex_view_automatic = 0

function Callback(msg)
  local m = vim.fn.matchlist(msg, "\\vRun number (\\d+) of rule ''(.*)''")
  if not vim.tbl_isempty(m) then
    vim.cmd "echomsg ' .. m[2] .. ' (' .. m[1] .. ')"
  end
end

vim.g.vimtex_compiler_latexmk = {
  backend = "nvim",
  background = 1,
  build_dir = "build/",
  callback = 1,
  continuous = 1,
  executable = "latexmk",
  hooks = {
    Callback,
  },
  options = {
    "-verbose",
    "-file-line-error",
    "-synctex=1",
    "-interaction=nonstopmode",
  },
}

vim.g.vimtex_toc_config = {
  split_pos = "full",
  layer_status = {
    label = 0,
  },
}

vim.g.vimtex_complete_bib = {
  simple = 0,
  menu_fmt = '@key @author_short (@year), "@title"',
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = "tex",
  callback = function()
    vim.keymap.set("n", "<Space>tt", "<Plug>(vimtex-toc-toggle)")
    vim.keymap.set("n", "<Space>tv", "<Plug>(vimtex-view)")
    vim.keymap.set("n", "<Space>tc", "<Plug>(vimtex-compile)")
    vim.keymap.set("n", "<C-F>", function()
      vim.cmd [[:call vimtex#fzf#run('cti', {'window': { 'width': 0.6, 'height': 0.6 } })]]
    end)
  end,
  desc = "VimTex key mappings",
})
