---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local tsutils = require "tsutils"
local autosnippet = require("luasnip").extend_decorator.apply(s, { snippetType = "autosnippet" })

local table_node
table_node = function(args)
  local tabs = {}
  local count
  table = args[1][1]:gsub("%s", ""):gsub("|", "")
  count = table:len()
  for j = 1, count do
    local iNode
    iNode = i(j)
    tabs[2 * j - 1] = iNode
    if j ~= count then
      tabs[2 * j] = t " & "
    end
  end
  return sn(nil, tabs)
end

local rec_table
rec_table = function()
  return sn(nil, {
    c(1, {
      t { "" },
      sn(nil, { t { "\\\\", "" }, d(1, table_node, { ai[1] }), d(2, rec_table, { ai[1] }) }),
    }),
  })
end

return {
  s(
    { trig = "skeleton", name = "LaTex Template" },
    fmta(
      [[
			\documentclass[10pt]{article}
			\usepackage[utf8]{inputenc}
			\title{<>}}
			\date{\today}
			\begin{document}
			\maketitle
			<>
			\end{document}
			]],
      { i(1, "Title"), i(0) }
    )
  ),
  parse({ trig = "tbf", name = "Bold text" }, "\\textbf{${1:${TM_SELECTED_TEXT}}} $0", {}),
  parse({ trig = "tit", name = "Italics text" }, "\\textit{${1:${TM_SELECTED_TEXT}}} $0", {}),
  parse({ trig = "ttt", name = "Typewriter text" }, "\\texttt{${1:${TM_SELECTED_TEXT}}} $0", {}),
  s({ trig = "foot", name = "Footnote" }, fmta("\\footnote{<>}<>", { i(1), i(0) })),
  s(
    { trig = "tbox", name = "Box around text" },
    fmta(
      [[
		\medskip
		\noindent\fbox{%
			\parbox{\textwidth}{%
				<>
			}%
		} \newline
	]],
      { i(0) }
    )
  ),
  s(
    { trig = "begin", name = "LaTex environment" },
    fmta(
      [[
    \begin{<>}
      \item <>
    \end{<>}
    ]],
      {
        i(1),
        i(0),
        rep(1),
      }
    )
  ),
  s(
    "itemize",
    fmta(
      [[
    \begin{itemize}
      \item <>
    \end{itemize}
    ]],
      {
        i(1),
      }
    )
  ),
  s(
    "enum",
    fmta(
      [[
    \begin{enumerate}
      \item <>
    \end{enumerate}
    ]],
      {
        i(1),
      }
    )
  ),
  s(
    "desc",
    fmta(
      [[
    \begin{description}
      \item[<>] <>
    \end{description}
    ]],
      {
        i(1),
        i(2),
      }
    )
  ),
  s(
    "eq",
    fmta(
      [[
    \begin{equation}
      <>
    \end{equation}
    ]],
      {
        i(1),
      }
    )
  ),
  s(
    "align",
    fmta(
      [[
    \begin{align}
      <>
    \end{align}
    ]],
      {
        i(1),
      }
    )
  ),
  s(
    { trig = "eqa", name = "Equation Array" },
    fmta(
      [[
			\begin{eqarray}
				<> & <> & <>
			\end{eqarray}
			]],
      {
        i(1),
        i(2),
        i(0),
      }
    )
  ),
  s("table", {
    t "\\begin{tabular}{",
    i(1, "0"),
    t { "}", "" },
    d(2, table_node, { 1 }, {}),
    d(3, rec_table, { 1 }),
    t { "", "\\end{tabular}" },
  }),

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

  s(
    "abs",
    fmta(
      [[
		\begin{abstract}
			<>
		\end{abstract}
	]],
      { i(0) }
    )
  ),

  s(
    "image",
    fmta(
      [[
			\begin{center}
			\includegraphics[width=<>}\linewidth]{<>}
			\end{center}
			<>
		]],
      { i(1, "0.8"), i(2), i(0) }
    )
  ),
  s(
    "fig",
    fmta(
      [[
			\begin{figure}[<>]
				\centering
				\includegraphics[width=<>}\linewidth]{<>}
				\caption{${4} <>}
				\label{fig:${4}}
			\end{figure}
			]],
      { i(1, "htpb"), i(2, "0.8"), i(3), i(0) }
    )
  ),
  s(
    "lst",
    fmta(
      [[
		\begin{lstlisting}[caption=<>,captionpos=b]
			<>
		\end{lstlisting}
		<>
		]],
      { i(1), i(2), i(0) }
    )
  ),
  s(
    "newcmd",
    fmta(
      [[
		\newcommand{<>}[<>]{<>} <>
		]],
      { i(1, "cmd"), i(2, "opt"), i(3, "realcmd"), i(0) }
    )
  ),
  s("part", {
    t "\\part{",
    i(1),
    t { "}", "\\label{prt:" },
    l(l._1:lower():gsub("[%p%c%s]", ""), 1),
    t "}",
  }),
  s("chap", {
    t "\\chapter{",
    i(1),
    t { "}", "\\label{chap:" },
    l(l._1:lower():gsub("[%p%c%s]", ""), 1),
    t "}",
  }),
  s("sec", {
    t "\\section{",
    i(1),
    t { "}", "\\label{sec:" },
    l(l._1:lower():gsub("[%p%c%s]", ""), 1),
    t "}",
  }),
  s("sub", {
    t "\\subsection{",
    i(1),
    t { "}", "\\label{sub:" },
    l(l._1:lower():gsub("[%p%c%s]", ""), 1),
    t "}",
  }),
  s("ssub", {
    t "\\subsubsection{",
    i(1),
    t { "}", "\\label{ssub:" },
    l(l._1:lower():gsub("[%p%c%s]", ""), 1),
    t "}",
  }),
  s("par", {
    t "\\paragraph{",
    i(1),
    t { "}", "\\label{par:" },
    l(l._1:lower():gsub("[%p%c%s]", ""), 1),
    t "}",
  }),
  s("subp", {
    t "\\subparagraph{",
    i(1),
    t { "}", "\\label{subp:" },
    l(l._1:lower():gsub("[%p%c%s]", ""), 1),
    t "}",
  }),
}
