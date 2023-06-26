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
  local is_repo = vim.fn.system "git rev-parse --is-inside-work-tree"
  return vim.v.shell_error == 0
end

--- Get the comment string {beg,end} table
---@param ctype integer 1 for `line`-comment and 2 for `block`-comment
---@return table comment_strings {begcstring, endcstring}
M.get_cstring = function(ctype)
  local calculate_comment_string = require("Comment.ft").calculate
  local cutils = require "Comment.utils"
  -- use the `Comments.nvim` API to fetch the comment string for the region (eq. '--%s' or '--[[%s]]' for `lua`)
  local cstring = calculate_comment_string { ctype = ctype, range = cutils.get_region() }
    or vim.bo.commentstring
  -- as we want only the strings themselves and not strings ready for using `format` we want to split the left and right side
  local left, right = cutils.unwrap_cstr(cstring)
  -- create a `{left, right}` table for it
  return { left, right }
end

M.bash = function(callback, args, user_args)
  local handle = io.popen(user_args)
  local result = {}
  for line in handle:lines() do
    table.insert(result, line)
  end
  handle:close()
  return result
end

M.osascript = function(callback, args, user_args)
  local handle = io.popen("/usr/bin/osascript -e " .. string.format("%q", user_args))
  local result = {}
  for line in handle:lines() do
    table.insert(result, line)
  end
  handle:close()
  return result
end

M.get_visual = function(args, parent)
  local ls = require "luasnip"
  local sn = ls.snippet_node
  local i = ls.insert_node
  if #parent.snippet.env.SELECT_RAW > 0 then
    return sn(nil, i(1, parent.snippet.env.SELECT_RAW))
  else
    return sn(nil, i(1, ""))
  end
end

M.get_openai_token = function()
	local result = ""
	-- check if security executable is available and OS is macos
	if vim.fn.executable("security") == 1 or vim.fn.has("macunix") == 1 then
		local handle = io.popen("security find-generic-password -s openai-api-key -w")
		result = handle:read("*a")
		handle:close()
	end
	-- -- check if on Linux
	-- if vim.fn.has("unix") == 1 then
	-- 	local handle = io.popen("pass OpenAI")
	-- 	result = handle:read("*a")
	-- 	handle:close()
	-- end
	return result
end

return M
