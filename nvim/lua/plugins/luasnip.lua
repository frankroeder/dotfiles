local M = { "L3MON4D3/LuaSnip", tag = "v2.0.0" }

function M.config()
  local status_ok, luasnip = pcall(require, "luasnip")
  if not status_ok then
    return
  end

  local lua = require("luasnip.loaders.from_lua")

  luasnip.setup {
    history = true,
    update_events = "TextChanged,TextChangedI",
    delete_check_events = "TextChanged",
    ext_opts = {
      [require "luasnip.util.types".choiceNode] = {
        active = {
          virt_text = { { "choiceNode", "Comment" } },
        },
      },
    },
    -- minimal increase in priority.
    ext_prio_increase = 1,
    enable_autosnippets = true,
    -- mapping for cutting selected text so it's usable as SELECT_DEDENT,
    -- SELECT_RAW or TM_SELECTED_TEXT (mapped via xmap).
    store_selection_keys = "<Tab>",
		-- resolve current filetype from cursor in e.g. markdown code blocks or `vim.cmd()`
    ft_func = require("luasnip.extras.filetype_functions").from_cursor
  }

	luasnip.filetype_extend("zsh", { "sh" })
	luasnip.filetype_extend("typescript", { "javascript" })
	luasnip.filetype_extend("svelte", { "javascript" })

  -- custom lua snippets
  lua.load({ paths = os.getenv("HOME") .. "/.config/nvim/snippets/" })

	vim.cmd([[command! LuaSnipEdit :lua require("luasnip.loaders.from_lua").edit_snippet_files()]])
	vim.cmd([[command! LuaSnipReload :lua require("luasnip.loaders.from_lua").load({paths = "~/.config/nvim/snippets/"})]])
	vim.keymap.set({ "i", "s" }, "<C-J>", function() luasnip.jump(1) end, { desc = "LuaSnip forward jump" })
	vim.keymap.set({ "i", "s" }, "<C-K>", function() luasnip.jump(-1) end, { desc = "LuaSnip backward jump" })
	vim.keymap.set({ "i", "s" }, "<C-L>", function() luasnip.expand() end, { desc = "LuaSnip expand" })
end

return M
