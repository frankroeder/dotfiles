local gh = require("pack_helpers").gh

vim.pack.add({ gh("ibhagwan/fzf-lua") }, { load = false })

if #vim.api.nvim_list_uis() == 0 then
  return
end

vim.cmd.packadd "fzf-lua"

do
  local fzf = require "fzf-lua"

  fzf.setup({
    winopts = { split = "aboveleft new" },
    previewers = {
      builtin = {
        render_markdown = { enabled = false },
      },
    },
    actions = {
      files = {
        enter = fzf.actions.file_edit,
      },
    },
  })

  vim.keymap.set("i", "<C-x><C-f>", function()
    fzf.complete_file({
      cmd = "rg --files",
      winopts = { preview = { hidden = "nohidden" } },
    })
  end, { silent = true, desc = "Fuzzy complete file" })

  vim.keymap.set("n", "<C-T>", function()
    local is_git_repo = require("utils").is_git_repo
    if is_git_repo() then
      fzf.git_files({ file_icons = false, git_icons = false })
    else
      fzf.files({ file_icons = false, git_icons = false })
    end
  end, { desc = "files / git files" })

  vim.keymap.set("n", "<C-F>", function()
    fzf.grep_project({ file_icons = false, git_icons = false })
  end, { desc = "file lines" })

  vim.keymap.set("n", "<C-B>", fzf.buffers, { desc = "buffers" })
  vim.keymap.set("n", "<C-P>", fzf.lgrep_curbuf, { desc = "buffer lines" })
  vim.keymap.set("n", "<Leader>t", fzf.colorschemes, { desc = "colorschemes" })
  vim.keymap.set("n", "<C-H>", fzf.help_tags, { desc = "help tags" })
  vim.keymap.set("n", "<Leader>:", fzf.commands, { desc = "vim commands" })
  vim.keymap.set("n", "<Leader>g", fzf.git_commits, { desc = "git commits" })
  vim.keymap.set("n", "<Leader>m", fzf.keymaps, { desc = "keymaps" })
  vim.keymap.set("n", "<Leader>k", fzf.marks, { desc = "marks" })
  vim.keymap.set("n", "<Leader>p", fzf.lsp_document_symbols, { desc = "document symbols" })
  vim.keymap.set("n", "<Leader>h", fzf.command_history, { desc = "command history" })
  vim.keymap.set("n", [[<Leader>"]], fzf.registers, { desc = "registers" })
  vim.keymap.set("n", [[<Leader>tb]], fzf.tmux_buffers, { desc = "tmux buffers" })
end
