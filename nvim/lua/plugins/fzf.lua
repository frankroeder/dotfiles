return {
  { "junegunn/fzf", dir = "~/.fzf", build = "./install --bin" },
  {
    "ibhagwan/fzf-lua",
    opts = {
      winopts = { split = "aboveleft new" },
    },
    keys = {
      {
        "<C-T>",
        function()
          local is_git_repo = require("utils").is_git_repo
          if is_git_repo() then
            require("fzf-lua").git_files { file_icons = false, git_icons = false }
          else
            require("fzf-lua").files { file_icons = false, git_icons = false }
          end
        end,
        desc = "files / git files",
      },
      {
        "<C-F>",
        [[<cmd>lua require('fzf-lua').grep_project({ file_icons=false, git_icons=false })<CR>]],
        desc = "file lines",
      },
      { "<C-B>", [[<cmd>lua require('fzf-lua').buffers()<CR>]], desc = "buffers" },
      { "<C-P>", [[<cmd>lua require('fzf-lua').lgrep_curbuf()<CR>]], desc = "buffer Lines" },
      { "<Leader>t", [[<cmd>lua require('fzf-lua').colorschemes()<CR>]], desc = "colorschemes" },
      { "<C-H>", [[<cmd>lua require('fzf-lua').help_tags()<CR>]], desc = "help tags" },
      { "<Leader>:", [[<cmd>lua require('fzf-lua').commands()<CR>]], desc = "vim commands" },
      { "<Leader>g", [[<cmd>lua require('fzf-lua').git_commits()<CR>]], desc = "git commits" },
      { "<Leader>m", [[<cmd>lua require('fzf-lua').keymaps()<CR>]], desc = "keymaps" },
      { "<Leader>k", [[<cmd>lua require('fzf-lua').marks()<CR>]], desc = "marks" },
      {
        "<Leader>p",
        [[<cmd>lua require('fzf-lua').lsp_document_symbols()<CR>]],
        desc = "document symbols",
      },
      {
        "<Leader>h",
        [[<cmd>lua require('fzf-lua').command_history()<CR>]],
        desc = "command history",
      },
      { [[<Leader>"]], [[<cmd>lua require('fzf-lua').registers()<CR>]], desc = "registers" },
    },
  },
}
