local M = {}

function M.gh(repo)
  return "https://github.com/" .. repo
end

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.ERROR, { title = "vim.pack" })
end

function M.add_runtime(path)
  local normalized = vim.fs.normalize(vim.fn.expand(path))
  if not vim.uv.fs_stat(normalized) then
    return nil
  end

  if not vim.tbl_contains(vim.opt.runtimepath:get(), normalized) then
    vim.opt.runtimepath:append(normalized)
  end

  return normalized
end

return M
