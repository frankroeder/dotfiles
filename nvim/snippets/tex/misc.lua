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
  s(
    { trig = "gloss", name = "Glossary Entry" },
    fmta(
      [[
      \newglossaryentry{<>}{
        name = {<>},
        symbol = {\ensuremath{<>}},
        description = {<>}
      }
      <>
      ]],
      { i(1, "entry"), i(2, "name"), i(3, "symbol"), i(4, "description"), i(0) }
    )
  ),
  s(
    { trig = "acro", name = "Acronym Entry" },
    fmta(
      [[
      \newacronym{<>}{<>}{<>}
      <>
      ]],
      { i(1, "entry"), i(2, "acronym"), i(3, "expansion"), i(0) }
    )
  ),
}
