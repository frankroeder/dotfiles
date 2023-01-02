---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local tsutils = require "tsutils"

return {
  parse("#!", "#!/usr/bin/env python3\n# -*- coding: utf-8 -*-\n"),
  parse("plt", "import matplotlib.pyplot as plt"),
  parse("np", "import numpy as np"),
  parse("pd", "import pandas as pd"),
  parse({ trig = "ipdb", name = "ipdb breakpoint" }, "import ipdb; ipdb.set_trace()"),

  s({ trig = "pr", name = "print" }, {
    t "print(",
    i(1),
    t ")",
  }),
  s({ trig = "doc", name = "Documentation block" }, {
    t [["""]],
    i(1),
    t [["""]],
  }),

  s(
    { trig = "if", name = "If Statement" },
    fmta(
      [[
			if <>:
				<>
			]],
      { i(1), i(2, "pass") }
    )
  ),
  s(
    { trig = "ife", name = "If / Else Statement" },
    fmta(
      [[
			if <>:
				<>
			else:
				<>
			]],
      { i(1), i(2, "pass"), i(3, "pass") }
    )
  ),
  s(
    { trig = "ifee", name = "If / Elif / Else Statement" },
    fmta(
      [[
			if <>:
				<>
			elif <>:
				<>
			else:
				<>
			]],
      { i(1, "cond"), i(2, "pass"), i(3, "cond"), i(4, "pass"), i(5, "pass") }
    )
  ),

  s({ trig = "ifmain", name = "if main" }, {
    t [[if __name__ == "__main__":\n]],
    i(1, { "main()" }),
  }),
  s(
    { trig = "try", name = "Try/Except" },
    fmta(
      [[
			try:
				<>
			except <> as <>:
				<>
			]],
      { i(1), i(2, "Exception"), i(3, "e"), i(4, "raise") }
    )
  ),
  s(
    { trig = "trye", name = "Try/Except/Else" },
    fmta(
      [[
			try:
				<>
			except <> as <>:
				<>
			else:
				<>
			]],
      { i(1), i(2, "Exception"), i(3, "e"), i(4, "raise"), i(5, "pass") }
    )
  ),
  s(
    { trig = "tryf", name = "Try/Except/Finally" },
    fmta(
      [[
			try:
				<>
			except <> as <>:
				<>
			finally:
				<>
			]],
      { i(1), i(2, "Exception"), i(3, "e"), i(4, "raise"), i(5, "pass") }
    )
  ),
  s(
    { trig = "tryef", name = "Try/Except/Else/Finally" },
    fmta(
      [[
			try:
				<>
			except <> as <>:
				<>
			else:
				<>
			finally:
				<>
			]],
      { i(1), i(2, "Exception"), i(3, "e"), i(4, "raise"), i(5, "pass"), i(6, "pass") }
    )
  ),
  s(
    { trig = "skeleton", name = "Python Template" },
    fmta(
      [[
			def main():
				<>

			if __name__ == '__main__':
				main()
			]],
      { i(1) }
    )
  ),
}
