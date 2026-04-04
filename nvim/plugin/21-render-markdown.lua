local gh = require("pack_helpers").gh

vim.pack.add({
  gh("nvim-tree/nvim-web-devicons"),
  gh("MeanderingProgrammer/render-markdown.nvim"),
})

require("render-markdown").setup({
  anti_conceal = {
    enabled = true,
  },
  win_options = {
    conceallevel = {
      default = 0,
      rendered = 3,
    },
    concealcursor = {
      default = vim.api.nvim_get_option_value("concealcursor", {}),
      rendered = "",
    },
  },
  file_types = { "markdown", "Avante" },
  completions = {
    blink = { enabled = true },
    lsp = { enabled = true },
  },
})

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("render_markdown_keymaps", { clear = true }),
  pattern = { "markdown", "Avante" },
  callback = function(ev)
    vim.keymap.set("n", "<Space>tt", "<cmd>RenderMarkdown toggle<CR>", {
      buffer = ev.buf,
      desc = "Toggle markdown rendering",
    })
  end,
})
