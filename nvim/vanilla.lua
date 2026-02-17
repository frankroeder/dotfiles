-- Config taken from https://github.com/yobibyte/yobitools/blob/main/dotfiles/init.lua
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.o.clipboard = "unnamedplus"
vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.autoread = true
vim.o.timeoutlen = 300
vim.o.wildignorecase = true
vim.g.netrw_banner = 0
vim.opt.path:append "**"
vim.opt.wildignore:append { "*.venv/*", "*/.git/*", "*/target/*", "*/__pycache__/*, */wandb/*" }
vim.cmd "syntax off | colorscheme retrobox"
vim.api.nvim_set_hl(0, "Normal", { fg = "#ffaf00" })
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
  pattern = "*",
})
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local space_count, tab_count, min_indent = 0, 0, 8
    for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 100, false)) do
      local indent = line:match "^(%s+)"
      if indent and not line:match "^%s*$" then
        if indent:find "\t" then
          tab_count = tab_count + 1
        else
          space_count = space_count + 1
          min_indent = math.min(min_indent, #indent)
        end
      end
    end
    if tab_count <= space_count then
      vim.opt_local.expandtab, vim.opt_local.shiftwidth, vim.opt_local.tabstop, vim.opt_local.softtabstop =
        true, min_indent, min_indent, min_indent
    end
  end,
})
local function scratch_to_quickfix()
  local items, bufnr = {}, vim.api.nvim_get_current_buf()
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line ~= "" then
      local filename, lnum, text = line:match "^([^:]+):(%d+):(.*)$"
      if filename and lnum then
        table.insert(
          items,
          { filename = vim.fn.fnamemodify(filename, ":p"), lnum = tonumber(lnum), text = text }
        ) -- for grep filename:line:text
      else
        local lnum, text = line:match "^(%d+):(.*)$"
        if lnum and text then
          table.insert(
            items,
            { filename = vim.fn.bufname(vim.fn.bufnr "#"), lnum = tonumber(lnum), text = text }
          ) -- for current buffer grep
        else
          table.insert(items, { filename = vim.fn.fnamemodify(line, ":p") }) -- for find results, only fnames
        end
      end
    end
  end
  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.fn.setqflist(items, "r")
  vim.cmd "copen | cc"
end
local function extcmd(cmd, use_list, quickfix)
  if use_list then
    output = vim.fn.systemlist(cmd)
  else
    output = vim.fn.system(vim.split(output, "\n"))
  end
  if not output or #output == 0 then
    return
  end
  vim.cmd "vnew"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  if quickfix then
    scratch_to_quickfix()
  end
end
vim.api.nvim_create_user_command("FileSearch", function(opts)
  local excludes =
    "-path '*.egg-info*' -prune -o -path '*/.git*' -prune -o -path '*__pycache__*' -prune -o -path '*wandb/*' -prune -o"
  if vim.bo.filetype == "netrw" then
    path = vim.b.netrw_curdir
  else
    path = vim.fn.getcwd()
    excludes = excludes
      .. " -path '*/.venv*' -prune -o"
      .. " -path '"
      .. path
      .. "/target*'"
      .. " -prune -o"
  end
  extcmd(
    "find "
      .. vim.fn.shellescape(path)
      .. " "
      .. excludes
      .. " "
      .. " -name "
      .. "'*"
      .. opts.args
      .. "*' -print",
    true,
    true
  )
end, { nargs = "+" })
vim.api.nvim_create_user_command("GrepTextSearch", function(opts)
  local path, excludes =
    "",
    "--exclude-dir='*target*' --exclude-dir=.git --exclude-dir='*.egg-info' --exclude-dir='__pycache__' --exclude-dir='wandb'"
  if vim.bo.filetype == "netrw" then
    path = vim.b.netrw_curdir
  else
    path = vim.fn.getcwd()
    excludes = excludes .. " --exclude-dir=.venv"
  end
  extcmd("grep -IEnr " .. excludes .. " '" .. opts.args .. "' " .. path, true, true)
end, { nargs = "+" })
vim.keymap.set("n", "<leader>q", ":q!<cr>")
vim.keymap.set("n", "<leader>d", ":bd<cr>")
vim.keymap.set("n", "<leader>f", ":find **/*")
vim.keymap.set("n", "<leader><space>", ":b ")
vim.keymap.set("n", "<C-n>", ":cn<cr>")
vim.keymap.set("n", "<C-p>", ":cp<cr>")
vim.keymap.set("n", "<C-q>", ":cclose<cr>")
vim.keymap.set("n", "<leader>n", ":bn<cr>")
vim.keymap.set("n", "<leader>p", ":bp<cr>")
vim.keymap.set("n", "<leader>e", ":Explore<cr>")
vim.keymap.set("n", "<leader>w", ":set number!<cr>")
vim.keymap.set("n", "<leader>so", ":browse oldfiles<cr>")
vim.keymap.set("n", "<leader>x", scratch_to_quickfix)
vim.keymap.set("n", "<leader>gl", function()
  extcmd({ "git", "log" }, true)
end)
vim.keymap.set("n", "<leader>gd", function()
  extcmd({ "git", "diff" }, true)
end)
vim.keymap.set("n", "<leader>gb", function()
  extcmd({ "git", "blame", vim.fn.expand "%" }, true)
end)
vim.keymap.set("n", "<leader>gs", function()
  extcmd({ "git", "show", vim.fn.expand "<cword>" }, true)
end)
vim.keymap.set("n", "<leader>gp", function()
  vim.cmd(
    "edit "
      .. vim.fn.system("python3 -c 'import site; print(site.getsitepackages()[0])'"):gsub(
        "%s+$",
        ""
      )
      .. "/."
  )
end)
vim.keymap.set("n", "<leader>gr", function()
  local registry = os.getenv "CARGO_HOME" or (os.getenv "HOME" .. "/.cargo") .. "/registry/src"
  vim.cmd("edit " .. registry .. "/" .. vim.fn.systemlist("ls -1 " .. registry)[1])
end)
vim.keymap.set("n", "<leader>ss", function()
  vim.ui.input({ prompt = "> " }, function(pat)
    if pat then
      extcmd(
        "grep -in '" .. pat .. "' " .. vim.fn.shellescape(vim.api.nvim_buf_get_name(0)),
        true,
        false
      )
    end
  end)
end)
vim.keymap.set("n", "<leader>sg", function()
  vim.ui.input({ prompt = "> " }, function(pat)
    if pat then
      vim.cmd("GrepTextSearch " .. pat)
    end
  end)
end)
vim.keymap.set("n", "<leader>sf", function()
  vim.ui.input({ prompt = "> " }, function(pat)
    if pat then
      vim.cmd("FileSearch " .. pat)
    end
  end)
end)
vim.keymap.set("n", "<leader>bb", ":!black %<cr>")
vim.keymap.set("n", "<leader>br", function()
  extcmd({ "ruff", "check", vim.fn.expand "%", "--output-format=concise", "--quiet" }, true)
end)
