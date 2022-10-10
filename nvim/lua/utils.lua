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

return M
