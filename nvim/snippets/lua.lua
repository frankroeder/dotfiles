---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local utils = require "utils"

return {
  s({ trig = "pr", name = "print" }, {
    t "print(",
    d(1, utils.get_visual),
    t ")",
  }),
  s({ trig = "pri", name = "print vim.inspect" }, {
    t "print(vim.inspect(",
    d(1, utils.get_visual),
    t "))",
  }),
  s(
    {
      trig = "req",
      name = "Import statement",
      dscr = "This snippet creates an import statement for the specified module.",
    },
    c(1, {
      sn(nil, fmt([[ require("{}") ]], { i(1, "module") })),
      sn(nil, fmt([[ local {} = require("{}") ]], { i(1, "name"), i(2, "module") })),
    })
  ),
  s(
    { trig = "m", name = "Module" },
    fmt(
      [[
      local M = {{}}

      M.{}

      return M
      ]],
      i(0)
    )
  ),
  s(
    { trig = "function", name = "Different function types" },
    c(1, {
      sn(
        nil,
        fmta([[ function(<>) <> end ]], { i(1, "params"), i(2, "body") }),
        { name = "One-liner" }
      ),
      sn(
        nil,
        fmta(
          [[
				function(<>)
					<>
				end ]],
          { i(1, "params"), i(2, "body") }
        ),
        { name = "Anonymous function" }
      ),
      sn(
        nil,
        fmta(
          [[
				local function <>(<>)
					<>
				end ]],
          { i(1, "name"), i(2, "params"), i(3, "body") }
        ),
        { name = "Regular function" }
      ),
    })
  ),
}
