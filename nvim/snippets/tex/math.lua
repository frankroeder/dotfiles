---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local tsutils = require "tsutils"
local autosnippet = require("luasnip").extend_decorator.apply(s, { snippetType = "autosnippet" })

return {
  s("frac", fmta("\\frac{<>}{<>}", { i(1), i(2) }), { condition = tsutils.in_mathzone }),
  s("prod", fmta("\\prod_{<>}{<>}", { i(1), i(2) }), { condition = tsutils.in_mathzone }),
  s(
    "int",
    fmta("\\int_{<>}{<>}", { i(1, "-\\infty"), i(2, "\\infty") }),
    { condition = tsutils.in_mathzone }
  ),
  s("sqrt", fmta("\\sqrt{<>}<>", { i(1), i(0) }), { condition = tsutils.in_mathzone }),
  s("lim", fmta("\\lim_{<>}^{<>}", { i(1), i(2, "\\infty") }), { condition = tsutils.in_mathzone }),
  s("sum", fmta("\\sum_{<>}^{<>}<>", { i(1), i(2), i(0) }), { condition = tsutils.in_mathzone }),
  s(
    { trig = "lr{", name = "left right", dsc = "Left right with curly brackets/braces" },
    fmta("\\left\\{ <> \\right\\}", { i(1) }),
    { condition = tsutils.in_mathzone }
  ),
  s(
    { trig = "lr(", name = "left right", dsc = "Left right with round brackets/parentheses" },
    fmta("\\left\\( <> \\right\\)", { i(1) }),
    { condition = tsutils.in_mathzone }
  ),
  s(
    { trig = "lr[", name = "left right", dsc = "Left right with square brackets/brackets" },
    fmta("\\left\\[ <> \\right\\]", { i(1) }),
    { condition = tsutils.in_mathzone }
  ),
  s(
    { trig = "dv", name = "Derivative" },
    fmta("\\dv[<>]{<>}{<>}", { i(1), i(2), i(3) }),
    { condition = tsutils.in_mathzone }
  ),
  s(
    { trig = "pdv", name = "Partial Derivative" },
    fmta("\\pdv[<>]{<>}{<>}", { i(1), i(2), i(3) }),
    { condition = tsutils.in_mathzone }
  ),

  autosnippet(
    { trig = "(%a)(%d)", regTrig = true, name = "auto subscript", dscr = "hi" },
    fmta([[<>_<>]], {
      f(function(_, snip)
        return snip.captures[1]
      end),
      f(function(_, snip)
        return snip.captures[2]
      end),
    }),
    { condition = tsutils.in_mathzone }
  ),
  autosnippet(
    {
      trig = "(%a)_(%d%d)",
      regTrig = true,
      name = "auto subscript 2",
      dscr = "auto subscript for 2+ digits",
    },
    fmta([[<>_{<>}]], {
      f(function(_, snip)
        return snip.captures[1]
      end),
      f(function(_, snip)
        return snip.captures[2]
      end),
    }),
    { condition = tsutils.in_mathzone }
  ),
  autosnippet(
    { trig = "(%a)+hat", regTrig = true, name = "hats", dscr = "Replaces x+hat with \\hat{x}" },
    fmt(
      [[\hat{<>}]],
      { f(function(_, snip)
        return snip.captures[1]
      end) },
      { delimiters = "<>" }
    )
  ),
}
