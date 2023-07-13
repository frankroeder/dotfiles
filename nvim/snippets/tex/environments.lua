---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()

local table_node = function(args)
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
    ),
    { condition = line_begin }
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
    "enumerate",
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
				\includegraphics[width=<>\linewidth]{<>}
				\caption{<>}
				\label{fig:<>}
			\end{figure}
			]],
      { i(1, "htpb"), i(2, "0.8"), i(3), i(4), i(0) }
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
    { trig = "cases", name = "Cases environment" },
    fmta(
      [[
    \begin{cases}
       <> \\
       <> \\
    \end{cases}
    ]],
      {
        i(1, "case a"),
        i(2, "case b"),
      }
    )
  ),
}
