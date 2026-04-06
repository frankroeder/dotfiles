local pack = require "pack_helpers"

local function pack_complete(arg_lead)
  local ok, plugins = pcall(vim.pack.get)
  if not ok then
    return {}
  end

  local names = vim.iter(plugins)
    :map(function(plugin)
      return plugin.spec.name
    end)
    :filter(function(name)
      return vim.startswith(name, arg_lead)
    end)
    :totable()

  table.sort(names)
  return names
end

local function pack_names(opts)
  if opts and opts.fargs and #opts.fargs > 0 then
    return opts.fargs
  end

  return nil
end

vim.api.nvim_create_user_command("PackUpdate", function(opts)
  vim.pack.update(pack_names(opts), { force = opts.bang })
end, {
  nargs = "*",
  bang = true,
  complete = pack_complete,
  desc = "Update plugins managed by vim.pack",
})

vim.api.nvim_create_user_command("PackStatus", function(opts)
  vim.pack.update(pack_names(opts), { force = opts.bang, offline = true })
end, {
  nargs = "*",
  bang = true,
  complete = pack_complete,
  desc = "Inspect current plugin state without fetching updates",
})

vim.api.nvim_create_user_command("PackSync", function(opts)
  vim.pack.update(pack_names(opts), { force = opts.bang, target = "lockfile" })
end, {
  nargs = "*",
  bang = true,
  complete = pack_complete,
  desc = "Synchronize plugins to the lockfile state",
})

vim.api.nvim_create_user_command("PackClean", function()
  local inactive = vim.iter(vim.pack.get())
    :filter(function(plugin)
      return not plugin.active
    end)
    :map(function(plugin)
      return plugin.spec.name
    end)
    :totable()

  if vim.tbl_isempty(inactive) then
    pack.notify("No inactive plugins to delete", vim.log.levels.INFO)
    return
  end

  vim.pack.del(inactive)
end, {
  desc = "Delete plugins no longer referenced by the config",
})
