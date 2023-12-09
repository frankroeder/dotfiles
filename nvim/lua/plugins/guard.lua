local M = {
  "nvimdev/guard.nvim",
  dependencies = {
    "nvimdev/guard-collection",
  },
  event = { "BufReadPre", "BufNewFile" },
}

function M.config()
  local guard = require "guard"
  local gft = require "guard.filetype"
  gft("python"):lint("ruff"):fmt("isort"):append "ruff"
  gft("c,cpp"):lint("clang-tidy"):fmt "clang-format"
  gft("go"):fmt "gofmt"
  gft("lua"):fmt "stylua"
  gft("json"):fmt {
    cmd = "jq",
    stdin = true,
  }
  gft("typescript,javascript,typescriptreact"):lint {
    cmd = "eslint",
    stdin = true,
  }

  guard.setup {
    fmt_on_save = false,
    lsp_as_default_formatter = false,
  }
end
function M.keys()
  return {
    {
      "<Space>cf",
      function()
        vim.cmd [[GuardFmt]]
      end,
      mode = { "n", "v" },
      desc = "[c]ode [f]ormat",
    },
  }
end

return M
