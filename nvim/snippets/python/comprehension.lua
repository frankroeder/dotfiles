---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
-- shout out to friendly-snippets

return {
  s(
    { trig = "lc", name = "List comprehension", dscr = "[val for val in Iterator]" },
    fmt("[{} for {} in {}]", {
      extras.rep(2),
      i(2, "val"),
      i(1, "Iterator"),
    })
  ),
  s(
    {
      trig = "lcif",
      name = "List comprehension with if-statement",
      dscr = "[val for val in Iterator if condition]",
    },
    fmt("[{} for {} in {}, if {}]", {
      extras.rep(2),
      i(2, "val"),
      i(1, "Iterator"),
      i(3, "condition"),
    })
  ),
  s(
    { trig = "dc", name = "Dict comprehension", dscr = "{key: val for key, val in Iterator}" },
    fmta("{<>: <> for <>, <> in <>}", {
      extras.rep(2),
      extras.rep(3),
      i(2, "key"),
      i(3, "val"),
      i(1, "Iterator"),
    })
  ),
  s(
    {
      trig = "dcif",
      name = "Dict comprehension with if-statement",
      dscr = "{key: val for key, val in Iterator if condition}",
    },
    fmta("{<>: <> for <>, <> in <> if <>}", {
      extras.rep(2),
      extras.rep(3),
      i(2, "key"),
      i(3, "val"),
      i(1, "Iterator"),
      i(3, "condition"),
    })
  ),
  s(
    { trig = "sc", name = "Set comprehension", dscr = "{val for val in Iterator}" },
    fmta("{<> for <> in <>}", {
      extras.rep(2),
      i(2, "val"),
      i(1, "Iterator"),
    })
  ),
  s(
    {
      trig = "scif",
      name = "Set comprehension with if-condition",
      dscr = "{val for val in Iterator if condition}",
    },
    fmta("{<> for <> in <> if <>}", {
      extras.rep(2),
      i(2, "val"),
      i(1, "Iterator"),
      i(3, "condition"),
    })
  ),
  s(
    { trig = "sc", name = "Generator comprehension", dscr = "(val for val in Iterator)" },
    fmt("({} for {} in {})", {
      i(2, "key"),
      i(3, "val"),
      i(1, "Iterator"),
    })
  ),
  s(
    {
      trig = "scif",
      name = "Generator comprehension with if-condition",
      dscr = "(val for val in Iterator if condition)",
    },
    fmt("({} for {} in {} if {})", {
      i(2, "key"),
      i(3, "val"),
      i(1, "Iterator"),
      i(3, "condition"),
    })
  ),
}
