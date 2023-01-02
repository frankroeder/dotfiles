---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local tsutils = require "tsutils"

return {
  s({
    trig = "link",
    namr = "markdown_link",
    dscr = "Create markdown link [txt](url)",
  }, {
    t "[",
    i(1),
    t "](",
    f(function(_, snip)
      return snip.env.TM_SELECTED_TEXT[1] or {}
    end, {}),
    t ")",
    i(0),
  }),
  parse({ trig = "sec", name = "Section" }, "# ${1:${TM_SELECTED_TEXT}} #\n$0", {}),
  parse({ trig = "sub", name = "Subsection" }, "## ${1:${TM_SELECTED_TEXT}} ##\n$0", {}),
  parse({ trig = "ssub", name = "Subsubsection" }, "### ${1:${TM_SELECTED_TEXT}} ###\n$0", {}),
  parse({ trig = "par", name = "Paragraph" }, "#### ${1:${TM_SELECTED_TEXT}} ####\n$0", {}),
  parse({ trig = "spar", name = "Subparagraph" }, "##### ${1:${TM_SELECTED_TEXT}} #####\n$0", {}),

  parse({ trig = "bold", name = "Inline code" }, "**${1:${TM_SELECTED_TEXT}}**$0", {}),
  parse({ trig = "italics", name = "Inline code" }, "*${1:${TM_SELECTED_TEXT}}*$0", {}),
  parse({ trig = "bolditalics", name = "Inline code" }, "***${1:${TM_SELECTED_TEXT}}***$0", {}),
  parse({ trig = "code", name = "Inline code" }, "`${1:${TM_SELECTED_TEXT}}`$0", {}),
  s(
    { trig = "codeblock", name = "Codeblock" },
    fmt(
      [[
			```{}
			{}
			```
			{}
			]],
      { i(2), i(1), i(0) }
    )
  ),
  s(
    { trig = "img", name = "Image" },
    fmt(
      [[
			[{}]({} "{}") {}
			]],
      { i(1, "alt text"), i(2, "source"), i(3, "title"), i(0) }
    )
  ),
  s(
    { trig = "link", name = "Link" },
    fmt(
      [[
			[{}]({}) {}
			]],
      { i(1, "text"), i(2, "link"), i(0) }
    )
  ),
}
