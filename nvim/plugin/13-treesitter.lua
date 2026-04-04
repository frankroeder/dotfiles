local gh = require("pack_helpers").gh
local pack = require "pack_helpers"

local function prepare_treesitter_install()
  local install = require "nvim-treesitter.install"
  local abi = vim.treesitter.language_version
  if abi then
    install.ts_generate_args = { "generate", "--abi", tostring(abi) }
  else
    install.ts_generate_args = { "generate" }
  end
end

vim.api.nvim_create_autocmd("PackChanged", {
  desc = "Handle nvim-treesitter installs and updates",
  group = vim.api.nvim_create_augroup("nvim-treesitter-pack-changed-update-handler", { clear = true }),
  callback = function(event)
    if event.data.spec.name ~= "nvim-treesitter" then
      return
    end

    if event.data.kind ~= "install" and event.data.kind ~= "update" then
      return
    end

    vim.schedule(function()
      if not event.data.active then
        vim.cmd.packadd "nvim-treesitter"
      end

      prepare_treesitter_install()

      local ok, err = pcall(vim.cmd, "TSUpdate")
      if not ok then
        pack.notify(("nvim-treesitter update failed:\n%s"):format(err))
      end
    end)
  end,
})

vim.pack.add({
  {
    src = gh("nvim-treesitter/nvim-treesitter"),
    version = "master",
  },
})

local function fix_query_predicates_for_nvim_012()
  pcall(require, "nvim-treesitter.query_predicates")

  local query = require "vim.treesitter.query"
  local opts = { force = true }

  local html_script_type_languages = {
    ["importmap"] = "json",
    ["module"] = "javascript",
    ["application/ecmascript"] = "javascript",
    ["text/ecmascript"] = "javascript",
  }

  local non_filetype_match_injection_language_aliases = {
    ex = "elixir",
    pl = "perl",
    sh = "bash",
    uxn = "uxntal",
    ts = "typescript",
  }

  local function get_parser_from_markdown_info_string(injection_alias)
    local match = vim.filetype.match { filename = "a." .. injection_alias }
    return match or non_filetype_match_injection_language_aliases[injection_alias] or injection_alias
  end

  local function valid_args(name, pred, count, strict_count)
    local arg_count = #pred - 1

    if strict_count then
      if arg_count ~= count then
        vim.api.nvim_err_writeln(string.format("%s must have exactly %d arguments", name, count))
        return false
      end
    elseif arg_count < count then
      vim.api.nvim_err_writeln(string.format("%s must have at least %d arguments", name, count))
      return false
    end

    return true
  end

  local function get_capture_node(match, capture_id)
    local captured = match[capture_id]
    if not captured then
      return nil
    end
    if type(captured) ~= "table" then
      return captured
    end
    return captured[1]
  end

  query.add_predicate("nth?", function(match, _, _, pred)
    if not valid_args("nth?", pred, 2, true) then
      return
    end

    local node = get_capture_node(match, pred[2])
    local n = tonumber(pred[3])
    if node and node:parent() and node:parent():named_child_count() > n then
      return node:parent():named_child(n) == node
    end

    return false
  end, opts)

  query.add_predicate("is?", function(match, _, bufnr, pred)
    if not valid_args("is?", pred, 2) then
      return
    end

    local locals = require "nvim-treesitter.locals"
    local node = get_capture_node(match, pred[2])
    local types = { table.unpack(pred, 3) }

    if not node then
      return true
    end

    local _, _, kind = locals.find_definition(node, bufnr)
    return vim.tbl_contains(types, kind)
  end, opts)

  query.add_predicate("kind-eq?", function(match, _, _, pred)
    if not valid_args(pred[1], pred, 2) then
      return
    end

    local node = get_capture_node(match, pred[2])
    local types = { table.unpack(pred, 3) }

    if not node then
      return true
    end

    return vim.tbl_contains(types, node:type())
  end, opts)

  query.add_directive("set-lang-from-mimetype!", function(match, _, bufnr, pred, metadata)
    local capture_id = pred[2]
    local node = get_capture_node(match, capture_id)
    if not node then
      return
    end

    local type_attr_value = vim.treesitter.get_node_text(node, bufnr)
    local configured = html_script_type_languages[type_attr_value]
    if configured then
      metadata["injection.language"] = configured
    else
      local parts = vim.split(type_attr_value, "/", {})
      metadata["injection.language"] = parts[#parts]
    end
  end, opts)

  query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
    local capture_id = pred[2]
    local node = get_capture_node(match, capture_id)
    if not node then
      return
    end

    local injection_alias = vim.treesitter.get_node_text(node, bufnr):lower()
    metadata["injection.language"] = get_parser_from_markdown_info_string(injection_alias)
  end, opts)

  query.add_directive("make-range!", function() end, opts)

  query.add_directive("downcase!", function(match, _, bufnr, pred, metadata)
    local capture_id = pred[2]
    local node = get_capture_node(match, capture_id)
    if not node then
      return
    end

    local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[capture_id] }) or ""
    if not metadata[capture_id] then
      metadata[capture_id] = {}
    end
    metadata[capture_id].text = string.lower(text)
  end, opts)
end

local function resolve_parser_install_dir()
  local candidates = {
    vim.fs.joinpath(vim.fn.stdpath "data", "site"),
    vim.fs.joinpath(vim.fn.stdpath "state", "site"),
    vim.fs.joinpath(vim.fn.stdpath "cache", "site"),
  }

  local function is_writable_parser_dir(path)
    local parser_dir = vim.fs.joinpath(path, "parser")
    local probe = vim.fs.joinpath(parser_dir, ".nvim-write-test")
    local ok = pcall(vim.fn.mkdir, probe, "p")
    if ok and vim.fn.isdirectory(probe) == 1 then
      vim.fn.delete(probe, "rf")
      return true
    end
    return false
  end

  for _, candidate in ipairs(candidates) do
    local ok = pcall(vim.fn.mkdir, candidate, "p")
    if ok and vim.fn.isdirectory(candidate) == 1 and is_writable_parser_dir(candidate) then
      return candidate
    end
  end

  return candidates[1]
end

local parser_install_dir = resolve_parser_install_dir()

prepare_treesitter_install()
fix_query_predicates_for_nvim_012()

if not vim.tbl_contains(vim.opt.runtimepath:get(), parser_install_dir) then
  vim.opt.runtimepath:append(parser_install_dir)
end

require("nvim-treesitter.configs").setup({
  parser_install_dir = parser_install_dir,
  ensure_installed = require("settings").treesitter_ensure_installed,
  auto_install = true,
  ignore_install = {},
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
    disable = {
      "csv",
    },
  },
  indent = {
    enable = true,
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<C-n>",
      node_incremental = "<C-n>",
      scope_incremental = false,
      node_decremental = "<C-p>",
    },
  },
})
