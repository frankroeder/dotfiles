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
    { trig = "ci", name = "console info" },
    fmt("console.info({})", {
      d(1, utils.get_visual),
    })
  ),
  s(
    { trig = "cd", name = "console debug" },
    fmt("console.debug({})", {
      d(1, utils.get_visual),
    })
  ),
  s(
    { trig = "ce", name = "console error" },
    fmt("console.error({})", {
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
  s({ trig = "req", dscr = "require('module')" }, fmt("require({})", { i(1, "module") })),
  s(
    { trig = "ima", dscr = "import ... from .." },
    fmt("import {} from {}", {
      i(2, "alias"),
      i(1, "module"),
    })
  ),
  s(
    { trig = "if", name = "If Statement" },
    fmta(
      [[
			if (<>) {
				<>
      }]],
      { i(1, "condition"), i(2) }
    )
  ),
  s(
    { trig = "ife", name = "If / Else Statement" },
    fmta(
      [[
			if (<>) {
				<>
      } else {
				<>
      }]],
      { i(1, "condition"), i(2), i(3) }
    )
  ),
  s(
    { trig = "switch", name = "switch statement" },
    fmta(
      [[
			switch (<>) {
        case	<>:
          <>
        default:
          <>
      }]],
      { i(1, "expr"), i(2, "match"), i(3), i(4) }
    )
  ),
  s(
    { trig = "func", name = "Define a function" },
    fmta(
      [[
      function <>() {
        <>
      }]],
      { i(1, "name"), i(2, "body") }
    )
  ),
  s(
    { trig = "map", dscr = "Array prototype map" },
    fmt("{}.map({} => {})", {
      i(1, "iterable"),
      i(2, "item"),
      i(3),
    })
  ),
  s(
    { trig = "reduce", dscr = "Array prototype reduce" },
    fmt("{}.reduce(({}, {}) => {} + {}, {})", {
      i(1, "iterable"),
      i(2, "accumulator"),
      i(3, "currentValue"),
      i(4, "accumulator"),
      i(5, "currentValue"),
      i(6, "initialValue"),
    })
  ),
  s(
    { trig = "find", dscr = "Array prototype find" },
    fmt("{}.map({} => {})", {
      i(1, "iterable"),
      i(2, "element"),
      i(3, "condition"),
    })
  ),
}
