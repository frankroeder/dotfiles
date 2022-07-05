local install_path = vim.fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
  packer_bootstrap = vim.fn.system({
    'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path
  })
  print "Installing packer close and reopen Neovim..."
  vim.cmd [[packadd packer.nvim]]
end

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

-- Install your plugins here
return packer.startup({function(use)
  use 'wbthomason/packer.nvim'

  use {
    'preservim/nerdcommenter', config = [[require('config.nerdcommenter')]]
  }
  use {
    'junegunn/fzf', dir = '~/.fzf', run = './install --bin'
  }
  use 'junegunn/fzf.vim'
  use 'tpope/vim-surround'
  use 'tpope/vim-repeat'

  use {
    'nvim-treesitter/nvim-treesitter', requires = {'p00f/nvim-ts-rainbow'},
    config = [[require('config.treesitter')]], run = ':TSUpdate',
  }

  use {
    'neovim/nvim-lspconfig', config = [[require('config.lsp')]],
    after="cmp-nvim-lsp"
  }
  use {
    "hrsh7th/nvim-cmp",
    config = [[require('config.nvim_cmp')]],
  }
  use {
    "quangnguyen30192/cmp-nvim-ultisnips",
    requires = { "hrsh7th/nvim-cmp", "SirVer/ultisnips" },
  }
  use {
    "SirVer/ultisnips",
    config = [[require('config.ultisnips')]]
  }
  use { "hrsh7th/cmp-nvim-lsp", requires = { "hrsh7th/nvim-cmp" } }
  use { "hrsh7th/cmp-buffer", requires = { "hrsh7th/nvim-cmp" } }
  use { "hrsh7th/cmp-path", requires = { "hrsh7th/nvim-cmp" } }
  use { "hrsh7th/cmp-nvim-lua", requires = { "hrsh7th/nvim-cmp" } }
  use { "hrsh7th/cmp-omni", requires = { "hrsh7th/nvim-cmp" } }
  use { "ray-x/cmp-treesitter", requires = { "hrsh7th/nvim-cmp" } }
  use { "windwp/nvim-autopairs", requires = { "hrsh7th/nvim-cmp" } }

  use 'github/copilot.vim'
  use {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    config = function ()
      vim.schedule(function() require("copilot").setup({
				ft_disable = { "text", "markdown", "latex" },
      }) end)
    end,
    requires = {
      {"zbirenbaum/copilot-cmp", after = "copilot.lua"}
    }
  }

  -- utils
  use 'nvim-lua/plenary.nvim'
  use {
    'jose-elias-alvarez/null-ls.nvim',
    config = [[require('config.null_ls')]]
  }
  use {
    'kyazdani42/nvim-tree.lua',
    config = [[require('config.nvim_tree')]],
    requires = { 'kyazdani42/nvim-web-devicons' },
  }
  use {
    'simrat39/symbols-outline.nvim', config = [[require('config.symbols_outline')]]
  }
  use { 'lewis6991/gitsigns.nvim', requires = {'nvim-lua/plenary.nvim'},
    config = [[require('config.gitsigns')]], event = "BufRead"
  }
  use {
    'lukas-reineke/indent-blankline.nvim',
    config = [[require('config.indent_blankline')]]
  }
	use {
		"folke/which-key.nvim",
		config = function()
			require("which-key").setup {
				spelling = {
					enabled = true, -- enabling this will show WhichKey when pressing z= to select spelling suggestions
					suggestions = 20, -- how many suggestions should be shown in the list?
				},
			}
		end
	}
  -- language support
  use {
    'plasticboy/vim-markdown', requires = { 'godlygeek/tabular' }
  }
  use 'lervag/vim-latex'
  use 'frankroeder/apple-swift'
  use 'cespare/vim-toml'

  -- ui
  use {
    'nvim-lualine/lualine.nvim', config = [[require('config.lualine')]],
    requires = { 'kyazdani42/nvim-web-devicons', opt = true }
  }
  use {
    'romgrk/barbar.nvim', config = [[require('config.barbar')]]
  }

  -- colorschemes
  use 'joshdick/onedark.vim'
  use {
    "catppuccin/nvim", as = "catppuccin",
    config = [[require('config.colorscheme')]]
  }

  if packer_bootstrap then
    require('packer').sync()
  end
end,
  config = {
    display = {
      -- use a popup window
      open_fn = function()
        return require("packer.util").float { border = "rounded" }
      end,
    }
  }})
