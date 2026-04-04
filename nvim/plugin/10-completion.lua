local pack = require "pack_helpers"
local gh = pack.gh

vim.api.nvim_create_autocmd("PackChanged", {
  desc = "Handle blink.cmp installs and updates",
  group = vim.api.nvim_create_augroup("blink-cmp-pack-changed-handler", { clear = true }),
  callback = function(event)
    if event.data.spec.name ~= "blink.cmp" then
      return
    end

    if event.data.kind ~= "install" and event.data.kind ~= "update" then
      return
    end

    if vim.fn.executable "cargo" ~= 1 then
      pack.notify("cargo is not available, skipping blink.cmp build", vim.log.levels.WARN)
      return
    end

    local result = vim.system({ "cargo", "build", "--release" }, { cwd = event.data.path, text = true }):wait()
    if result.code ~= 0 then
      local output = result.stderr ~= "" and result.stderr or result.stdout
      pack.notify(("blink.cmp build failed:\n%s"):format(output))
    end
  end,
})

vim.pack.add({
  { src = gh("L3MON4D3/LuaSnip"), version = vim.version.range "2.x" },
  gh("archie-judd/blink-cmp-words"),
  gh("folke/lazydev.nvim"),
  gh("saghen/blink.cmp"),
})

do
  local status_ok, luasnip = pcall(require, "luasnip")
  if status_ok then
    local lua = require "luasnip.loaders.from_lua"

    luasnip.setup({
      update_events = "TextChanged,TextChangedI",
      delete_check_events = "TextChanged",
      ext_opts = {
        [require("luasnip.util.types").choiceNode] = {
          active = {
            virt_text = { { "choiceNode", "Comment" } },
          },
        },
      },
      ext_prio_increase = 1,
      enable_autosnippets = true,
      store_selection_keys = "<Tab>",
      ft_func = require("luasnip.extras.filetype_functions").from_cursor,
    })

    luasnip.filetype_extend("zsh", { "sh" })
    luasnip.filetype_extend("typescript", { "javascript" })
    luasnip.filetype_extend("svelte", { "javascript" })

    lua.load({ paths = vim.fn.stdpath "config" .. "/snippets/" })

    vim.cmd [[command! LuaSnipEdit :lua require("luasnip.loaders").edit_snippet_files()]]
    vim.cmd [[command! LuaSnipReload :lua require("luasnip.loaders.from_lua").load({paths = vim.fn.stdpath("config") .. "/snippets/"})]]

    vim.keymap.set({ "i", "s" }, "<C-J>", function()
      require("luasnip").jump(1)
    end, { desc = "LuaSnip forward jump" })

    vim.keymap.set({ "i", "s" }, "<C-K>", function()
      require("luasnip").jump(-1)
    end, { desc = "LuaSnip backward jump" })

    vim.keymap.set({ "i", "s" }, "<C-L>", function()
      require("luasnip").expand()
    end, { desc = "LuaSnip expand" })
  end
end

require("lazydev").setup({
  library = {
    vim.fs.normalize(vim.fn.expand "~/Documents/luapos/parrot.nvim"),
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    { path = "snacks.nvim", words = { "Snacks" } },
  },
})

require("blink.cmp").setup({
  keymap = {
    preset = "enter",
    ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
    ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
    ["<Up>"] = {},
    ["<Down>"] = {},
    ["<C-J>"] = {},
    ["<C-K>"] = {},
  },
  enabled = function()
    return vim.bo.buftype ~= "prompt" and vim.bo.buftype ~= "oil" and vim.b.completion ~= false
  end,
  snippets = {
    preset = "luasnip",
    jump = function(direction)
      require("luasnip").change_choice(direction)
    end,
  },
  completion = {
    keyword = {
      range = "full",
    },
    list = {
      max_items = 100,
      selection = {
        preselect = false,
      },
    },
    accept = {
      auto_brackets = {
        enabled = true,
      },
    },
    menu = {
      auto_show = true,
      draw = {
        treesitter = { "lsp" },
      },
    },
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 150,
    },
    ghost_text = { enabled = false },
  },
  signature = {
    enabled = true,
  },
  appearance = {
    use_nvim_cmp_as_default = true,
    kind_icons = {
      Boolean = "",
      Class = "󰠱",
      Color = "󰏘",
      Constant = "󰏿",
      Constructor = "",
      Enum = "",
      EnumMember = "",
      Event = "",
      Field = "󰜢",
      File = "󰈙",
      Folder = "󰉋",
      Function = "󰡱",
      Interface = "",
      Keyword = "󰌋",
      Method = "󰆧",
      Module = "",
      Namespace = "",
      Operator = "󰆕",
      Property = "󰜢",
      Reference = "󰈇",
      Snippet = "",
      Struct = "󰙅",
      TypeParameter = "󰬛",
      Unit = "󰑭",
      Value = "󰎠",
      Variable = "󰀫",
    },
  },
  cmdline = {
    enabled = true,
    completion = {
      menu = { auto_show = true },
    },
  },
  fuzzy = { implementation = "prefer_rust_with_warning" },
  sources = {
    default = function()
      local success, node = pcall(vim.treesitter.get_node)
      if success and node and vim.tbl_contains({ "comment", "line_comment", "block_comment" }, node:type()) then
        return { "buffer" }
      end

      if vim.bo.filetype == "tex" or vim.bo.filetype == "bib" then
        return { "buffer", "omni", "snippets", "thesaurus" }
      end

      local providers = { "lsp", "snippets", "path", "buffer", "parrot" }
      if vim.bo.filetype == "lua" then
        table.insert(providers, "lazydev")
      end
      if vim.bo.filetype == "markdown" then
        table.insert(providers, "markdown")
        table.insert(providers, "thesaurus")
      end
      return providers
    end,
    providers = {
      path = {
        opts = {
          show_hidden_files_by_default = true,
        },
      },
      buffer = {
        min_keyword_length = 2,
        max_items = 5,
      },
      lsp = {
        min_keyword_length = 2,
        fallbacks = { "lazydev" },
      },
      markdown = {
        name = "RenderMarkdown",
        module = "render-markdown.integ.blink",
        fallbacks = { "lsp" },
      },
      lazydev = {
        name = "LazyDev",
        module = "lazydev.integrations.blink",
        score_offset = 100,
      },
      parrot = {
        module = "parrot.completion.blink",
        name = "parrot",
        score_offset = 20,
        transform_items = function(_, items)
          for _, item in ipairs(items) do
            item.kind_icon = "🦜"
            item.kind_name = "parrot"
          end
          return items
        end,
      },
      thesaurus = {
        name = "blink-cmp-words",
        module = "blink-cmp-words.thesaurus",
        opts = {
          score_offset = 0,
          definition_pointers = { "!", "&", "^" },
        },
      },
    },
  },
})
