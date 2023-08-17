---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local line_begin = require("luasnip.extras.expand_conditions").line_begin
local utils = require "utils"

return {
  -- header
  s(
    { trig = "h([123456])", regTrig = true, wordTrig = false, snippetType = "autosnippet" },
    fmt(
      [[
          <h{} class="{}">{}</h{}>
        ]],
      {
        f(function(_, snip)
          return snip.captures[1]
        end),
        i(2),
        d(1, utils.get_visual),
        f(function(_, snip)
          return snip.captures[1]
        end),
      }
    ),
    { condition = line_begin }
  ),
  -- unordered list
  s(
    { trig = "ull" },
    fmt(
      [[
          <ul>
            <li {}>
              {}
            </li>{}
          </ul>
        ]],
      {
        i(2),
        i(1),
        i(0),
      }
    ),
    { condition = line_begin }
  ),
  -- list item
  s(
    { trig = "ii" },
    fmt(
      [[
            <li>
              {}
            </li>
        ]],
      {
        d(1, utils.get_visual),
      }
    ),
    { condition = line_begin }
  ),
  -- document skeleton
  s(
    { trig = "skeleton" },
    fmt(
      [[
        <!doctype HTML>
        <html lang="en">
          <head>
            <meta charset="UTF-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0" />
            <title>{}</title>
          </head>
          <body>
            {}
          </body>
        </html>
        ]],
      {
        i(1, "FooBar"),
        i(0),
      }
    ),
    { condition = line_begin }
  ),
  -- SCRIPT
  s(
    { trig = "js" },
    fmt(
      [[
          <script{}>
            {}{}
          </script>
        ]],
      {
        i(1),
        d(2, utils.get_visual),
        i(0),
      }
    ),
    { condition = line_begin }
  ),
  -- div
  s(
    { trig = "dd" },
    fmt(
      [[
          <div class="{}">
            {}{}
          </div>
        ]],
      {
        i(2),
        d(1, utils.get_visual),
        i(0),
      }
    ),
    { condition = line_begin }
  ),
  -- button
  s(
    { trig = "bb", snippetType = "autosnippet" },
    fmt(
      [[
          <button type="{}" {}>
            {}
          </button>
        ]],
      {
        i(1),
        i(2),
        d(3, utils.get_visual),
      }
    ),
    { condition = line_begin }
  ),
}
