return {
  { "junegunn/fzf", dir = "~/.fzf", build = "./install --bin" },
  {
    "ibhagwan/fzf-lua",
    config = function()
      local fzf_status_ok, fzf = pcall(require, "fzf-lua")
      if not fzf_status_ok then
        return
      end
      local is_git_repo = require("utils").is_git_repo
      local actions = require "fzf-lua.actions"

      fzf.setup {
        winopts = { split = "aboveleft new" },
        actions = {
          files = {
            ["default"] = actions.file_edit,
          },
        },
      }
      -- files
      if is_git_repo() then
        vim.keymap.set(
          "n",
          "<C-T>",
          [[<cmd>lua require('fzf-lua').git_files({ file_icons=false, git_icons=false })<CR>]]
        )
      else
        vim.keymap.set(
          "n",
          "<C-T>",
          [[<cmd>lua require('fzf-lua').files({ file_icons=false, git_icons=false })<CR>]]
        )
      end
      -- file lines
      vim.keymap.set(
        "n",
        "<C-F>",
        [[<cmd>lua require('fzf-lua').grep_project({ file_icons=false, git_icons=false })<CR>]]
      )
      -- vim buffers
      vim.keymap.set("n", "<C-B>", [[<cmd>lua require('fzf-lua').buffers()<CR>]])
      -- buffer lines
      vim.keymap.set("n", "<C-P>", [[<cmd>lua require('fzf-lua').lgrep_curbuf()<CR>]])
      -- colorschemes with preview
      vim.keymap.set("n", "<Leader>t", [[<cmd>lua require('fzf-lua').colorschemes()<CR>]])
      -- help tags
      vim.keymap.set("n", "<C-H>", [[<cmd>lua require('fzf-lua').help_tags()<CR>]])
      -- vim commands
      vim.keymap.set("n", "<Leader>:", [[<cmd>lua require('fzf-lua').commands()<CR>]])
      -- git commits
      vim.keymap.set("n", "<Leader>g", [[<cmd>lua require('fzf-lua').git_commits()<CR>]])
      -- defined keymaps
      vim.keymap.set("n", "<Leader>m", [[<cmd>lua require('fzf-lua').keymaps()<CR>]])
      -- vim marks
      vim.keymap.set("n", "<Leader>k", [[<cmd>lua require('fzf-lua').marks()<CR>]])
      vim.keymap.set(
        -- vim command history
        "n",
        "<Leader>h",
        [[<cmd>lua require('fzf-lua').command_history()<CR>]]
      )
      vim.keymap.set("n", [[<Leader>"]], [[<cmd>lua require('fzf-lua').registers()<CR>]])
    end,
  },
}
