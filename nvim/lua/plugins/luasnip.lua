local M = {
  "L3MON4D3/LuaSnip",
  tag = "v2.3.0",
  keys = {
    {
      "<C-T>",
      function()
        local is_git_repo = require("utils").is_git_repo
        if is_git_repo() then
          require("fzf-lua").git_files { file_icons = false, git_icons = false }
        else
          require("fzf-lua").files { file_icons = false, git_icons = false }
        end
      end,
      desc = "files / git files",
    },
    {
      "<C-J>",
      [[<cmd>lua require("luasnip").jump(1)<CR>]],
      mode = { "i", "s" },
      desc = "LuaSnip forward jump",
    },
    {
      "<C-K>",
      [[<cmd>lua require("luasnip").jump(-1)<CR>]],
      mode = { "i", "s" },
      desc = "LuaSnip backward jump",
    },
    {
      "<C-L>",
      [[<cmd>lua require("luasnip").expand()<CR>]],
      mode = { "i", "s" },
      desc = "LuaSnip expand",
    },
  },
}

function M.config()
  local status_ok, luasnip = pcall(require, "luasnip")
  if not status_ok then
    return
  end

  local lua = require "luasnip.loaders.from_lua"

  luasnip.setup {
    update_events = "TextChanged,TextChangedI",
    delete_check_events = "TextChanged",
    ext_opts = {
      [require("luasnip.util.types").choiceNode] = {
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
    ft_func = require("luasnip.extras.filetype_functions").from_cursor,
  }

  luasnip.filetype_extend("zsh", { "sh" })
  luasnip.filetype_extend("typescript", { "javascript" })
  luasnip.filetype_extend("svelte", { "javascript" })

  -- custom lua snippets
  lua.load { paths = os.getenv "HOME" .. "/.config/nvim/snippets/" }

  vim.cmd [[command! LuaSnipEdit :lua require("luasnip.loaders.from_lua").edit_snippet_files()]]
  vim.cmd [[command! LuaSnipReload :lua require("luasnip.loaders.from_lua").load({paths = "~/.config/nvim/snippets/"})]]
end

return M
