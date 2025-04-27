return {
  "williamboman/mason.nvim",
  build = ":MasonUpdate",
  cmd = "Mason",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    ui = {
      icons = {
        package_installed = "✓",
        package_pending = "➜",
        package_uninstalled = "✗",
      },
    },
    ensure_installed = {
      "clangd",
      "css-lsp",
      "ruff",
      "html-lsp",
      "lua-language-server",
      "svelte-language-server",
      "typescript-language-server",
      "basedpyright",
      "stylua",
    },
  },
  config = function(_, opts)
    require("mason").setup(opts)
    local mr = require "mason-registry"
    local function ensure_installed()
      for _, tool in ipairs(opts.ensure_installed) do
        local p = mr.get_package(tool)
        if not p:is_installed() then
          p:install()
        end
      end
    end
    if mr.refresh then
      mr.refresh(ensure_installed)
    else
      ensure_installed()
    end
  end,
  keys = {
    { "<Leader>lI", [[:Mason<CR>]], desc = "Open Mason" },
  },
}
