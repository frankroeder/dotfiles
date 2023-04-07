---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()

return {
  parse("#!", "#!/usr/bin/env python3\n# -*- coding: utf-8 -*-\n"),
  parse("plt", "import matplotlib.pyplot as plt"),
  parse("np", "import numpy as np"),
  parse("pd", "import pandas as pd"),
  parse("jnp", "import jax.numpy as jnp"),
  parse("fnn", "import flax.linen as nn"),
  parse("tnn", "import torch.nn as nn"),
  parse("tF", "import torch.nn.functional as F"),
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

  -- class
  s(
    "class",
    fmt(
      [[class {}({}):
    def __init__(self{}):
        {}{}]],
      { i(1, "FooBar"), i(2), i(3), i(4, "pass"), i(0) }
    )
  ),
  -- dataclass
  s(
    "classd",
    fmt(
      [[@dataclass
class {}:
    {}{}]],
      { i(1, "FooBar"), i(2, "pass"), i(0) }
    )
  ),
  -- function
  s(
    "def",
    fmt(
      [[def {}({}) -> {}:
    {}{}]],
      { i(1, "foo_bar"), i(2), i(3, "None"), i(4, "pass"), i(0) }
    )
  ),
  -- method
  s(
    "defs",
    fmt(
      [[def {}(self{}) -> {}:
    {}{}]],
      { i(1, "foo_bar"), i(2), i(3, "None"), i(4, "pass"), i(0) }
    )
  ),

  -- import ...
  s("im", fmt("import {}", { i(1, "package/module") })),
  -- import ... as ..
  s("ima", fmt("import {} as {}", { i(1, "package/module"), i(2, "alias") })),
  -- from ... import ...
  s("fim", fmt("from {} import {}", { i(1, "package/module"), i(2, "name") })),
  -- from ... import ... as ...
  s("fima", fmt("from {} import {} as {}", { i(1, "package/module"), i(2, "name"), i(3) })),

  -- if ...
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
  -- for-loop
  s(
    "for",
    fmt(
      [[for {} in {}:
    {}{}]],
      { i(1, "elem"), i(2, "iterable"), i(3, "pass"), i(0) }
    )
  ),
  -- for-loop in enumerate
  s(
    "fore",
    fmt(
      [[for i, {} in enumerate({}):
    {}{}]],
      { i(1, "elem"), i(2, "iterable"), i(3, "pass"), i(0) }
    )
  ),
  -- for-loop in range
  s(
    "forr",
    fmt(
      [[for i in range({}):
    {}{}]],
      { i(1, "iterable"), i(2, "pass"), i(0) }
    )
  ),
}
