local M = {}

-- merge two tables
M.merge_tables = function(t1, t2)
  for _, v in ipairs(t2) do
    table.insert(t1, v)
  end
  return t1
end

-- find element in table
M.table_find_element = function(table, element)
  for _, v in ipairs(table) do
    if v == element then
      return true
    end
  end
  return false
end

M.is_git_repo = function()
    local is_repo = vim.fn.system("git rev-parse --is-inside-work-tree")
    return vim.v.shell_error == 0
end

return M
