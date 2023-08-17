---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
return {
  parse(
    { trig = "sbash", name = "Safe Bash Options" },
    "#!/usr/bin/env bash\nset -euo pipefail\nIFS=$'\\n\\t'",
    {}
  ),
  s(
    { trig = "func", name = "function", dscr = "Define a function" },
    fmta(
      [[
		<>() {
				<>
		}
		]],
      { i(1), i(0) }
    )
  ),
  s(
    { trig = "for", name = "For Loop" },
    fmt(
      [[
			for (( i = 0; i < {}; i++ )); do
				{}
			done
	]],
      { i(1, "10"), i(0) }
    )
  ),
  s(
    { trig = "forin", name = "For In Loop" },
    fmta(
      [[
			for <> in <>; do
				<>
			done
	]],
      { i(1, "VAR"), i(2, "ITER"), i(0) }
    )
  ),
  s(
    "case",
    fmta(
      [[
		case <> in
			<> ) <>;;
		esac
    ]],
      {
        i(1),
        i(2),
        i(0),
      }
    )
  ),
  s(
    { trig = "if", name = "If Statment" },
    fmta("if [[ <> ]]; then\n  <>\nfi", { i(1, "condition"), i(0) })
  ),
  s(
    { trig = "elif", name = "Elif Statment" },
    fmta("elif [[ <> ]]; then\n  <>", { i(1, "condition"), i(0) })
  ),
  s(
    { trig = "until", name = "Until Loop" },
    fmta("until [[ <> ]]; do\n  <>\ndone", { i(1, "condition"), i(0) })
  ),
  s(
    { trig = "while", name = "While Loop" },
    fmta("while [[ <> ]]; do\n  <>\ndone", { i(1, "condition"), i(0) })
  ),
}
