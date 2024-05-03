local g = vim.g
local opt = vim.opt

local options = {
  completeopt = { "menu", "menuone", "noselect" },
  title = true, -- show file in title bar
  history = 200, -- 200 lines command history
  binary = true, -- Enable binary support
  wrap = false, -- Don't wrap long lines
  breakindent = true, -- wrap indent to match  line start
  scrolloff = 3, -- Keep at least 3 lines above/below
  sidescrolloff = 5, -- Show next 5 columns when scrolling sideways
  showmode = false, -- Don't show current mode
  showmatch = true, -- Show matching bracket/parenthesis/etc
  matchtime = 2,
  timeoutlen = 500,
  ruler = false,
  lazyredraw = true, -- redraw only when needed(not in execution of macro)
  synmaxcol = 2500, -- Limit syntax highlighting (this
  -- avoids the very slow redrawing
  -- when files contain long lines)
  updatetime = 300, -- faster update time for plugins like gitsigns
  signcolumn = "yes", -- always draw sign column
  cmdheight = 2,
  modeline = true,
  splitright = true, -- Vertical split right
  joinspaces = false, -- Use one space after punctuation
  -- indentation
  copyindent = true,
  smartindent = true,
  autoindent = true,
  smartindent = true,

  shiftwidth = 2, -- Preview tabs as 2 spaces
  shiftround = true,
  tabstop = 2, -- Tabs are 2 spaces
  softtabstop = 2, -- Columns a tab inserts in insert mode
  expandtab = true, -- expand tab to spaces

  -- search
  ignorecase = true, -- Search case insensitive
  smartcase = true, -- but changed if searched with upper case

  number = true, -- Print the line number in front of each line
  relativenumber = true,

  undofile = true, -- Persistent undo
  swapfile = false,
  backup = false,
  writebackup = false,
}

for k, v in pairs(options) do
  vim.opt[k] = v
end

opt.shortmess:append { c }

if vim.fn.has "clipboard" then
  opt.clipboard = "unnamed" -- copy to the system clipboard
  if vim.fn.has "unnamedplus" then -- X11 support
    opt.clipboard:append { unnamedplus = true }
  end
end

if vim.fn.has "mouse" then
  opt.mouse = "a"
  opt.mousehide = true -- Hide mouse when typing
end

g.python3_host_prog = vim.fn.exepath "python3"
opt.pyx = 3

-- Treat given characters as a word boundary
opt.iskeyword:remove { "." }
opt.iskeyword:remove { "#" }

g.mapleader = ","

-- Incrementing and decrementing alphabetical characters
opt.nrformats:append { "alpha" }
opt.matchpairs:append { "<:>" }

-- Ignore certain files and folders when globbing
opt.wildignorecase = true
opt.wildignore = {
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
}

opt.fillchars = {
  horiz = "━",
  horizup = "┻",
  horizdown = "┳",
  vert = "┃",
  vertleft = "┫",
  vertright = "┣",
  verthoriz = "╋",
}
