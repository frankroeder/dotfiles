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

local g = vim.g
local opt = vim.opt

opt.title = true            -- show file in title bar
opt.history = 200           -- 200 lines command history
opt.binary = true           -- Enable binary support
opt.wrap = false            -- Don't wrap long lines
opt.scrolloff = 3           -- Keep at least 3 lines above/below
opt.sidescrolloff = 5       -- Show next 5 columns when scrolling sideways
opt.showmode  = false       -- Don't show current mode
opt.showmatch = true        -- Show matching bracket/parenthesis/etc
opt.matchtime = 2
opt.ruler = false
opt.lazyredraw = true       -- redraw only when needed(not in execution of macro)
opt.synmaxcol = 2500        -- Limit syntax highlighting (this
                            -- avoids the very slow redrawing
                            -- when files contain long lines)
opt.updatetime = 300        -- faster updatetime for responsive async plugins like signify
opt.shortmess:append({ c })
opt.signcolumn = "yes"          -- always draw sign column
opt.cmdheight = 2
opt.modeline = true

if vim.fn.has("clipboard") then
  opt.clipboard = "unnamed"     -- copy to the system clipboard
  if vim.fn.has("unnamedplus") then  -- X11 support
    opt.clipboard:append { unnamedplus = true }
  end
end

opt.splitright = true           -- Vertical split right
opt.joinspaces = false          -- Use one space after punctuation

if vim.fn.has('mouse') then
  opt.mouse = a
  opt.mousehide = true          -- Hide mouse when typing
end

-- indentation
opt.copyindent = true       -- Copy indent structure when autoindenting
opt.backspace = "2"           -- make vim behave like any other editors
opt.cindent = true          --  Enables automatic C program indenting

opt.shiftwidth = 2          -- Preview tabs as 2 spaces
opt.shiftround = true
opt.tabstop = 2             -- Tabs are 2 spaces
opt.softtabstop = 2         -- Columns a tab inserts in insert mode
opt.expandtab = true        -- Tabs are spaces

-- search
opt.ignorecase = true       -- Search case insensitive...
opt.smartcase =  true       -- but change if searched with upper case

vim.g.python3_host_prog = vim.fn.exepath("python3")
opt.pyx = 3

-- syntax and style
if vim.fn.has('nvim') or vim.fn.has('termguicolors') then
  -- vim.call("let $NVIM_TUI_ENABLE_TRUE_COLOR=1")
  opt.termguicolors = true
end

opt.number = true
opt.relativenumber = true

-- Persistent undo
opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.writebackup = false

-- Treat given characters as a word boundary
opt.iskeyword:remove({"."})
opt.iskeyword:remove({"#"})

vim.g.mapleader = ","

vim.api.nvim_create_augroup("ReloadInit", {clear = true})
vim.api.nvim_create_autocmd("BufWritePost ", {
  group = "ReloadInit",
  pattern = "init.vim",
  callback = function ()
    vim.cmd("source % | echo 'Reloaded'")
  end,
})

-- Incrementing and decrementing alphabetical characters
opt.nrformats:append({ "alpha" })
opt.matchpairs:append({"<:>"})

-- Ignore certain files and folders when globbing
opt.wildignore = {}
opt.wildignore:append({
  "*.DS_Store",
  "*.bak",
  "*.class",
  "*.gif",
  "*.jpeg",
  "*.jpg",
  "*.min.js",
  "*.o",
  "*.obj",
  "*.out",
  "*.png",
  "*.pyc",
  "*.so",
  "*.swp",
  "*.zip",
  "*/*-egg-info/*",
  "*/.egg-info/*",
  "*/.expo/*",
  "*/.git/*",
  "*/.hg/*",
  "*/.mypy_cache/*",
  "*/.next/*",
  "*/.pnp/*",
  "*/.pytest_cache/*",
  "*/.repo/*",
  "*/.sass-cache/*",
  "*/.svn/*",
  "*/.venv/*",
  "*/.yarn/*",
  "*/.yarn/*",
  "*/__pycache__/*",
  "*/bower_modules/*",
  "*/build/*",
  "*/dist/*",
  "*/node_modules/*",
  "*/target/*",
  "*/venv/*",
  "*~",
})

opt.fillchars = { horiz = '━', horizup = '┻', horizdown = '┳', vert = '┃', vertleft = '┫', vertright = '┣', verthoriz = '╋', }

vim.cmd("highlight MatchParen gui=bold,reverse guifg=#413e3d guibg=#f9d39e")
require("config")
