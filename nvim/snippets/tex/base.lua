---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local tsutils = require "tsutils"

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
  parse(
		{ trig = "tbf", name = "Bold text" },
		"\\textbf{${1:${TM_SELECTED_TEXT}}} $0",
    { condition = tsutils.in_text }
	),
  parse(
		{ trig = "tit", name = "Italics text" },
		"\\textit{${1:${TM_SELECTED_TEXT}}} $0",
    { condition = tsutils.in_text }
	),
  parse(
		{ trig = "ttt", name = "Typewriter text" },
		"\\texttt{${1:${TM_SELECTED_TEXT}}} $0",
    { condition = tsutils.in_text }
	),
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
