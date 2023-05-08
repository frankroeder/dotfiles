---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local line_begin = require("luasnip.extras.expand_conditions").line_begin
local utils = require "utils"

return {
  s(
    { trig = "cl", name = "console log" },
    fmt("console.log({})", {
      d(1, utils.get_visual),
    })
  ),
  s(
    { trig = "for", name = "for-loop", dscr = "" },
    fmt([[for (let {} = 0; {} < {}.length; {}++)]], {
      i(1, "iter"),
      extras.rep(1),
      extras.rep(2),
      i(2, "object"),
    }),
    { condition = line_begin }
  ),
  s(
    { trig = "forin", name = "for-in loop", dscr = "for iter in object" },
    fmt([[for (const {} = 0 in {})]], {
      i(1, "iter"),
      i(2, "object"),
    }),
    { condition = line_begin }
  ),
  s(
    { trig = "foreach", name = "For-Each Loop", dscr = "For-Each Loop" },
    fmt("{}.forEach({} =>", {
      i(1, "array"),
      i(2, "element"),
    }),
    { condition = line_begin }
  ),
}
