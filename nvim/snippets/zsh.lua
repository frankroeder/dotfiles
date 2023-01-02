---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()
return {
  parse("#!", "#!/bin/zsh"),
  parse("!env", "#!/usr/bin/env zsh"),
}
