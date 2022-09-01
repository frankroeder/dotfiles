local M = {}
local DEFAULT_OPTS = { noremap = true, silent = true }

-- key map
M.keymap = function(mode, key, value, opts)
  local has_opts = opts ~= nil and not vim.tbl_isempty(opts)
  if has_opts then
    vim.api.nvim_set_keymap(mode, key, value, vim.tbl_extend("force", DEFAULT_OPTS, opts))
  else
    vim.api.nvim_set_keymap(mode, key, value, DEFAULT_OPTS)
  end
end

-- buffer key map
M.buf_keymap = function(bufnr, mode, key, value, opts)
  local has_opts = opts ~= nil and not vim.tbl_isempty(opts)
  if has_opts then
    vim.api.nvim_buf_set_keymap(
      bufnr,
      mode,
      key,
      value,
      vim.tbl_extend("force", DEFAULT_OPTS, opts)
    )
  else
    vim.api.nvim_buf_set_keymap(bufnr, mode, key, value, DEFAULT_OPTS)
  end
end

-- merge two tables
M.merge_tables = function(t1, t2)
  for k, v in ipairs(t2) do
    table.insert(t1, v)
  end
  return t1
end

-- find element in table
M.table_find_element = function(table, element)
  for k, v in ipairs(table) do
    if v == element then
      return true
    end
  end
  return false
end

return M
