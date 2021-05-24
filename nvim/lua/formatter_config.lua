local formatter = require 'formatter'
formatter.setup({
  logging = false,
  filetype = {
    python = {
      function()
        return {
          exe = vim.fn.exepath("yapf"),
          args = {
            "--quiet"
          },
          stdin = true
        }
      end
    },
    go = {
      function()
        return {
          exe = vim.fn.exepath("gofmt"),
          args = {"-s"},
          stdin = true
        }
      end
    }
  }
})

vim.cmd("nnoremap <silent> <F12> :Format<CR>")
