---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local utils = require "utils"

return {
  s({
    trig = "link",
    namr = "markdown_link",
    dscr = "Create markdown link [txt](url)",
  }, {
    t "[",
    i(1, "txt"),
    t "](",
    d(2, utils.get_visual),
    t ")",
    i(0),
  }),
  parse({ trig = "sec", name = "Section" }, "# ${1:${TM_SELECTED_TEXT}} #\n$0", {}),
  parse({ trig = "sub", name = "Subsection" }, "## ${1:${TM_SELECTED_TEXT}} ##\n$0", {}),
  parse({ trig = "ssub", name = "Subsubsection" }, "### ${1:${TM_SELECTED_TEXT}} ###\n$0", {}),
  parse({ trig = "par", name = "Paragraph" }, "#### ${1:${TM_SELECTED_TEXT}} ####\n$0", {}),
  parse({ trig = "spar", name = "Subparagraph" }, "##### ${1:${TM_SELECTED_TEXT}} #####\n$0", {}),
  s(
    { trig = "bold" },
    fmta([[**<>**]], {
      d(1, utils.get_visual),
    })
  ),
  s(
    { trig = "italics" },
    fmta([[*<>*]], {
      d(1, utils.get_visual),
    })
  ),
  s(
    { trig = "bolditalics" },
    fmta([[***<>***]], {
      d(1, utils.get_visual),
    })
  ),
  s(
    { trig = "code", name = "Inline code" },
    fmta([[`<>`]], {
      d(1, utils.get_visual),
    })
  ),
  s(
    { trig = "codeblock", name = "Codeblock" },
    fmt(
      [[
      ```{}
      {}
      ```
      ]],
      {
        i(1),
        d(2, utils.get_visual),
      }
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
