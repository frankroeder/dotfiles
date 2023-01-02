---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()

return {
  s(
    { trig = "coauthor", name = "Co-author" },
    fmt("Co-authored-by: {} <{}>", {
      i(1, "username"),
      i(2, "email"),
    })
  ),
}
