---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local utils = require "utils"

return {
  parse("#!", "#!/usr/bin/env python3\n# -*- coding: utf-8 -*-\n"),
  s({ trig = "pr", name = "print" }, {
    t "print(",
    d(1, utils.get_visual),
    t ")",
  }),
  s({ trig = "doc", name = "Documentation block" }, {
    t [["""]],
    i(1),
    t [["""]],
  }),
  s(
    { trig = "class", name = "Class" },
    fmt(
      [[class {}({}):
    def __init__(self{}):
        {}{}]],
      { i(1, "FooBar"), i(2), i(3), i(4, "pass"), i(0) }
    )
  ),
  s(
    { trig = "classd", name = "Dataclass" },
    fmt(
      [[@dataclass
class {}:
    {}{}]],
      { i(1, "FooBar"), i(2, "pass"), i(0) }
    )
  ),
  s(
    { trig = "def", name = "Different function types" },
    c(1, {
      sn(
        nil,
        fmt(
          [[
					def {}({}) -> {}:
						{}
					]],
          { i(1, "name"), i(2, "params"), i(3, "None"), i(4, "pass") }
        ),
        { name = "Regular function", desr = "def fn()" }
      ),
      sn(
        nil,
        fmt(
          [[
					def {}(self, {}) -> {}:
						{}
					]],
          { i(1, "name"), i(2, "params"), i(3, "None"), i(4, "pass") }
        ),
        { name = "Class method", desr = "def fn(self)" }
      ),
      sn(
        nil,
        fmt(
          [[
					@staticmethod
					def {}({}) -> {}:
						{}
					]],
          { i(1, "name"), i(2, "params"), i(3, "None"), i(4, "pass") }
        ),
        { name = "Staticmethod" }
      ),
      sn(
        nil,
        fmt(
          [[
					@classmethod
					def {}({}) -> {}:
						{}
					]],
          { i(1, "name"), i(2, "cls"), i(3, "None"), i(4, "pass") }
        ),
        { name = "Classmethod" }
      ),
    })
  ),
  s(
    { trig = "with", dscr = "with ... as ..." },
    fmt(
      [[with {} as {}:
    ]],
      {
        i(1, "expression"),
        i(2, "target"),
      }
    )
  ),
  s(
    { trig = "im", dscr = "import ..." },
    fmt("import {}", {
      i(1, "package/module"),
    })
  ),
  s(
    { trig = "ima", dscr = "import ... as .." },
    fmt("import {} as {}", {
      i(1, "package/module"),
      i(2, "alias"),
    })
  ),
  s(
    { trig = "fim", dscr = "from ... import ..." },
    fmt("from {} import {}", {
      i(1, "package/module"),
      i(2, "name"),
    })
  ),
  s(
    { trig = "fima", dscr = "from ... import ... as ..." },
    fmt("from {} import {} as {}", {
      i(1, "package/module"),
      i(2, "name"),
      i(3),
    })
  ),
  s(
    { trig = "if", name = "If Statement" },
    fmta(
      [[
			if <>:
				<>
			]],
      { i(1, "condition"), i(2, "pass") }
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
      { i(1, "condition"), i(2, "pass"), i(3, "pass") }
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
      { i(1, "condition"), i(2, "pass"), i(3, "condition"), i(4, "pass"), i(5, "pass") }
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
    { trig = "ipdbtry", name = "Try/Except" },
    fmta(
      [[
			try:
				<>
			except:
        import ipdb; ipdb.set_trace()
			]],
      {
        d(1, utils.get_visual),
      }
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
  s(
    { trig = "for", name = "for-loop", dscr = "for e in Iter" },
    fmt(
      [[for {} in {}:
    {}{}]],
      { i(1, "elem"), i(2, "iterable"), i(3, "pass"), i(0) }
    )
  ),
  s(
    { trig = "fore", name = "for-loop enumerate", dscr = "for i, e in enumerate(Iter)" },
    fmt(
      [[for i, {} in enumerate({}):
    {}{}]],
      { i(1, "elem"), i(2, "iterable"), i(3, "pass"), i(0) }
    )
  ),
  s(
    { trig = "forr", name = "for-loop range", dscr = "for i in range(...)" },
    fmt(
      [[for i in range({}):
    {}{}]],
      { i(1, "iterable"), i(2, "pass"), i(0) }
    )
  ),
}
