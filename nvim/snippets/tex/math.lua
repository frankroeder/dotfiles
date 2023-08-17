---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local tsutils = require "tsutils"
local autosnippet = require("luasnip").extend_decorator.apply(s, { snippetType = "autosnippet" })

return {
  s(
    { trig = "frac", dscr = "LaTex math fraction" },
    fmta("\\frac{<>}{<>}", { i(1, "numerator"), i(2, "denominator") }),
    { condition = tsutils.in_mathzone }
  ),
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
    { trig = "eu", dscr = "Euler's number" },
    fmta("e^{<>}", { i(1) }),
    { condition = tsutils.in_mathzone }
  ),
  s(
    { trig = "lr{", name = "left right", dsc = "Left right with curly brackets/braces" },
    fmta("\\left\\{ <> \\right\\}", { i(1) }),
    { condition = tsutils.in_mathzone }
  ),
  s(
    { trig = "lr(", name = "left right", dsc = "Left right with round brackets/parentheses" },
    fmta([[\left( <> \right)]], { i(1) }),
    { condition = tsutils.in_mathzone }
  ),
  s(
    { trig = "lr[", name = "left right", dsc = "Left right with square brackets/brackets" },
    fmta("\\left[ <> \\right]", { i(1) }),
    { condition = tsutils.in_mathzone }
  ),
  s(
    { trig = "lr|", name = "left right", dsc = "Left right with bars" },
    fmta("\\left\\| <> \\right\\|", { i(1) }),
    { condition = tsutils.in_mathzone }
  ),
  s(
    { trig = "lr<", name = "leftangle rightangle", dsc = "Left and right angle" },
    fmt("\\left< {} \\right>", { i(1) }),
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
    {
      trig = "(%a)(%d)",
      regTrig = true,
      name = "auto subscript single digit",
      dscr = "Auto subscript: typing x2 -> x_2",
    },
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
      name = "auto subscript two digits",
      dscr = "Auto subscript: typing x12 -> x_{12}",
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
    {
      trig = "(%a)+hat",
      regTrig = true,
      name = "hat",
      dscr = "Replaces x+hat with \\hat{x}",
    },
    fmt(
      [[\hat{<>}]],
      { f(function(_, snip)
        return snip.captures[1]
      end) },
      { delimiters = "<>" }
    ),
    { condition = tsutils.in_mathzone }
  ),
  autosnippet(
    {
      trig = "(%a)+bar",
      regTrig = true,
      name = "bar",
      dscr = "Replaces x+bar with \\overline{x}",
    },
    fmt(
      [[\overline{<>}]],
      { f(function(_, snip)
        return snip.captures[1]
      end) },
      { delimiters = "<>" }
    ),
    { condition = tsutils.in_mathzone }
  ),
  autosnippet({ trig = "<=", name = "Less equal" }, t "\\le", { condition = tsutils.in_mathzone }),
  autosnippet(
    { trig = ">=", name = "Greater equal" },
    t "\\ge",
    { condition = tsutils.in_mathzone }
  ),
  autosnippet(
    { trig = "->", name = "Right arrow" },
    t "\\rightarrow",
    { condition = tsutils.in_mathzone }
  ),
  s({ trig = "<-", name = "Left arrow" }, t "\\leftarrow", { condition = tsutils.in_mathzone }),
  s(
    { trig = "<->", name = "Left-right arrow" },
    t "\\leftrightarrow",
    { condition = tsutils.in_mathzone }
  ),
  autosnippet(
    { trig = "inf", name = "Infinity" },
    t "\\infty",
    { condition = tsutils.in_mathzone }
  ),
}
