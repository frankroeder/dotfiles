---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()

return {
  s(
    { trig = "hr", name = "hyperref package's href{}{} command for links" },
    fmta([[\href{<>}{<>}]], {
      i(1, "url"),
      i(2, "name"),
    })
  ),
}
