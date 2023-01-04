---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
local utils = require "utils"

local function math()
  return vim.api.nvim_eval "vimtex#syntax#in_mathzone()" == 1
end

local function env(name)
  local is_inside = vim.fn["vimtex#env#is_inside"](name)
  return (is_inside[1] > 0 and is_inside[2] > 0)
end

local function pick_comment_start_and_end()
  -- because lua block comment is unlike other language's,
  -- so handle lua ctype
  local ctype = 2
  if vim.opt.ft:get() == "lua" then
    ctype = 1
  end
  local cs = utils.get_cstring(ctype)[1]
  local ce = utils.get_cstring(ctype)[2]
  if ce == "" or ce == nil then
    ce = cs
  end
  return cs, ce
end

local get_comment_start = function()
  local cs, _ = pick_comment_start_and_end()
  return cs
end
local get_comment_end = function()
  local _, ce = pick_comment_start_and_end()
  return ce
end

local function create_box(opts)
  local pl = opts.padding_length or 4
  return {
    -- top line
    f(function(args)
      local cs, ce = pick_comment_start_and_end()
      return cs .. string.rep(string.sub(cs, #cs, #cs), string.len(args[1][1]) + 2 * pl) .. ce
    end, { 1 }),
    t { "", "" },
    f(function()
      local cs = pick_comment_start_and_end()
      return cs .. string.rep(" ", pl)
    end),
    i(1, "box"),
    f(function()
      local cs, ce = pick_comment_start_and_end()
      return string.rep(" ", pl) .. ce
    end),
    t { "", "" },
    -- bottom line
    f(function(args)
      local cs, ce = pick_comment_start_and_end()
      return cs .. string.rep(string.sub(ce, 1, 1), string.len(args[1][1]) + 2 * pl) .. ce
    end, { 1 }),
  }
end

return {
  parse(
    { trig = "lorem", name = "Placeholder text" },
    "Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod\n tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At\n vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren,\n no sea takimata sanctus est Lorem ipsum dolor sit amet.",
    {}
  ),
  s("modeline", {
    d(1, function()
      local str = vim.split(vim.bo.commentstring, "%s", true)

      return sn(nil, {
        t(str[1]),
        t " vim:ft=",
        i(1),
        t " ",
        t(str[2] or ""),
      })
    end, {}),
  }),
  s({ trig = "box", name = "Comment box" }, create_box { padding_length = 8 }),
  s({ trig = "bbox", name = "Bug comment box" }, create_box { padding_length = 20 }),

  s(
    { trig = "date", name = "Current date", dscr = "Date ion format Y-m-d" },
    p(os.date, "%Y-%m-%d")
  ),
  s("ddate", p(os.date, "%b-%d-%Y")),
  s({ trig = "diso", name = "Current date, ISO format" }, p(os.date, "%Y-%m-%d %H:%M:%S%z")),
  s("time", p(os.date, "%H:%M")),
  s("datetime", p(os.date, "%Y-%m-%d %H:%M")),
  s("htime", p(os.date, "%Y-%m-%dT%H:%M:%S+10:00")),
  s({ trig = "todo" }, {
    p(get_comment_start),
    t " ",
    c(1, { t "TODO", t "FIXME", t "NOTE", t "BUG", t "HACK", t "XXX" }),
    t " ",
    i(0),
    t " ",
    p(get_comment_end),
  }),

  s("bang", {
    t "#!/usr/bin/env ",
    c(1, {
      t "sh",
      t "bash",
      t "zsh",
      t "bash",
      t "python3",
      t "node",
    }),
  }, i(0)),

  s(
    { trig = "url", name = "Frontmost browser tab url" },
    f(utils.osascript, {}, {
      user_args = {
        'tell application "System Events" to get value of UI element 1 of combo box 1 of toolbar "Navigation" of first group of front window of application process "Firefox"',
      },
    })
  ),
  s(
    { trig = "uuid", name = "Generatre uuid", dscr = "Output of " .. vim.fn.exepath "uuidgen" },
    f(utils.bash, {}, { user_args = { "uuidgen" } })
  ),
}
