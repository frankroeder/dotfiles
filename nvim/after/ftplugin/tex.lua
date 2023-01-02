require("cmp").setup.buffer {
  -- preserve the format as provided by VimTeX
  formatting = {
    format = function(entry, vim_item)
      vim_item.menu = ({
        omni = (vim.inspect(vim_item.menu):gsub('%"', "")),
        buffer = "[Buffer]",
        ultisnips = "[USnips]",
        -- formatting for other sources
      })[entry.source.name]
      return vim_item
    end,
  },
  sources = {
    { name = "omni" },
    { name = "buffer", max_item_count = 5, keyword_length = 3 },
    { name = "ultisnips", max_item_count = 5 },
  },
}
