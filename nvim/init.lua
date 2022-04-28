---------------
--  VimPlug  --
---------------

local Plug = vim.fn['plug#']
vim.g.plug_dir = vim.fn.stdpath("data") .. "/plugged"

vim.call('plug#begin', vim.api.nvim_get_var("plug_dir"))

-- core
Plug 'preservim/nerdcommenter'
Plug('junegunn/fzf', { dir = '~/.fzf', ['do'] = vim.fn['./install --bin'] })
Plug 'junegunn/fzf.vim'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'

Plug 'neovim/nvim-lspconfig'
if vim.fn.executable("tree-sitter") and vim.fn.executable("node") then
  -- fix this
  Plug("nvim-treesitter/nvim-treesitter", {["do"] = vim.fn[":TSUpdate"]})
  Plug 'p00f/nvim-ts-rainbow'
end

-- completion utils
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-nvim-lua'
Plug 'hrsh7th/cmp-omni'
Plug 'ray-x/cmp-treesitter'
Plug 'windwp/nvim-autopairs'

-- Plug 'hrsh7th/cmp-copilot'
-- Plug 'github/copilot.vim'
Plug 'zbirenbaum/copilot.lua'
Plug 'zbirenbaum/copilot-cmp'

-- snippet support
Plug 'quangnguyen30192/cmp-nvim-ultisnips'
Plug 'SirVer/ultisnips'

-- utils
Plug 'nvim-lua/plenary.nvim'
Plug 'jose-elias-alvarez/null-ls.nvim'
Plug 'kyazdani42/nvim-tree.lua'
Plug 'liuchengxu/vista.vim'
Plug 'lewis6991/gitsigns.nvim'
Plug 'lukas-reineke/indent-blankline.nvim'

-- language support
Plug 'godlygeek/tabular'
Plug('plasticboy/vim-markdown', {depends = 'godlygeek/tabular'})
Plug('JamshedVesuna/vim-markdown-preview', { ['for'] = 'markdown' })
Plug 'lervag/vim-latex'
Plug 'frankroeder/apple-swift'
Plug 'cespare/vim-toml'

-- style
Plug 'nvim-lualine/lualine.nvim'
Plug 'romgrk/barbar.nvim'
Plug 'kyazdani42/nvim-web-devicons'

-- colorschemes
Plug 'joshdick/onedark.vim'
Plug('catppuccin/nvim' , { branch = 'old-catppuccino' })

vim.call('plug#end')

vim.cmd("highlight MatchParen gui=bold,reverse guifg=#413e3d guibg=#f9d39e")

require("options")
require("config")
require("keymaps")
