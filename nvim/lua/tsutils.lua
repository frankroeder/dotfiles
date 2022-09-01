-- This Lua module provides utility functions using nvim-treesitter to check the
-- node position in the AST.

local has_treesitter, ts = pcall(require, "vim.treesitter")
local _, query = pcall(require, "vim.treesitter.query")

local M = {}

local MATH_ENVIRONMENTS = {
  displaymath = true,
  equation = true,
  eqnarray = true,
  align = true,
  math = true,
  array = true,
}
local MATH_NODES = {
  displayed_equation = true,
  inline_formula = true,
}

local function get_node_at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_range = { cursor[1] - 1, cursor[2] }
  local buf = vim.api.nvim_get_current_buf()
  local ok, parser = pcall(ts.get_parser, buf, "latex")
  if not ok or not parser then
    return
  end
  local root_tree = parser:parse()[1]
  local root = root_tree and root_tree:root()

  if not root then
    return
  end

  return root:named_descendant_for_range(
    cursor_range[1],
    cursor_range[2],
    cursor_range[1],
    cursor_range[2]
  )
end

function M.in_comment()
  if has_treesitter then
    local node = get_node_at_cursor()
    while node do
      if node:type() == "comment" then
        return true
      end
      node = node:parent()
    end
    return false
  end
end

-- https://github.com/nvim-treesitter/nvim-treesitter/issues/1184#issuecomment-830388856
function M.in_mathzone()
  if has_treesitter then
    local buf = vim.api.nvim_get_current_buf()
    local node = get_node_at_cursor()
    while node do
      if MATH_NODES[node:type()] then
        return true
      elseif node:type() == "math_environment" or node:type() == "generic_environment" then
        local begin = node:child(0)
        local names = begin and begin:field "name"
        if
          names
          and names[1]
          and MATH_ENVIRONMENTS[query.get_node_text(names[1], buf):match "[A-Za-z]+"]
        then
          return true
        end
      end
      node = node:parent()
    end
    return false
  end
end

return M
