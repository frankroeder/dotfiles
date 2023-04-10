local M = {
      "nvim-tree/nvim-tree.lua",
      cmd = { "NvimTreeToggle" },
      dependencies = { "nvim-tree/nvim-web-devicons", lazy = true },
    }

function M.init()
	vim.keymap.set("n", "<Leader>n", ":NvimTreeToggle<CR>")
end

function M.config()
  local status_ok, nvim_tree = pcall(require, "nvim-tree")
  if not status_ok then
    return
  end

  -- recommended settings by nvim-tree
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1

  nvim_tree.setup {
    -- disables netrw completely
    disable_netrw = false,
    -- show lsp diagnostics in the signcolumn
    diagnostics = {
      enable = false,
      icons = {
        hint = "",
        info = "",
        warning = "",
        error = "",
      },
    },
    view = {
      centralize_selection = true,
      width = 32,
    },
    filters = {
      custom = {
        "^\\.git$",
        ".cache",
        ".vim",
        "__pycache__",
        "node_modules",
        ".egg-info",
        ".gitignore",
      },
      exclude = {
        "nvim"
      },
    },
  }

end

return M
