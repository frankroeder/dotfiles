return {
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "WhoIsSethDaniel/mason-tool-installer.nvim",
    },
    opts = {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
    keys = {
      { "<Leader>lI", [[:Mason<CR>]], desc = "Open Mason" },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = {
      "williamboman/mason.nvim",
    },
    opts = {
      ensure_installed = {
        "clangd",
        "css-lsp",
        "ruff",
        "html-lsp",
        "jedi-language-server",
        -- "lua_ls",
        "lua-language-server",
        "svelte-language-server",
        "typescript-language-server",
        "basedpyright",
      },
    },
  },
}
