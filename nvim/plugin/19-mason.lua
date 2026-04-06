local gh = require("pack_helpers").gh

vim.pack.add({
  gh("mason-org/mason.nvim"),
})

local opts = {
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
    "tinymist",
  },
}

require("mason").setup(opts)

local mr = require "mason-registry"

local function ensure_installed()
  for _, tool in ipairs(opts.ensure_installed) do
    local pkg = mr.get_package(tool)
    if not pkg:is_installed() then
      pkg:install()
    end
  end
end

if mr.refresh then
  mr.refresh(ensure_installed)
else
  ensure_installed()
end

vim.keymap.set("n", "<Leader>lI", "<cmd>Mason<CR>", { desc = "Open Mason" })
