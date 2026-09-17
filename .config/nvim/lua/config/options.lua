-- Core Neovim Options

local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & Indentation
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smarttab = true
opt.smartindent = true
opt.autoindent = true

-- Line wrapping
opt.wrap = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Cursor & Scrolling
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Appearance
opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"
opt.colorcolumn = ""  -- Disabled (was "100")

-- Behavior
opt.hidden = true
opt.errorbells = false
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.undodir = vim.fn.expand("~/.vim/undodir")
opt.autoread = true  -- Auto-reload files changed outside Neovim

-- Completion
opt.completeopt = { "menu", "menuone", "noselect" }
opt.pumheight = 10

-- Split windows
opt.splitright = true
opt.splitbelow = true

-- Subtle split lines
opt.fillchars = {
  vert = "│",
  horiz = "─",
  vertleft = "┤",
  vertright = "├",
  verthoriz = "┼",
}

-- Clipboard
opt.clipboard = "unnamedplus"

-- Update time
opt.updatetime = 50
opt.timeoutlen = 300
opt.ttimeout = true
opt.ttimeoutlen = 10

-- Encoding
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"

-- Status & Command line
opt.showmode = false  -- Shown in statusline instead
opt.laststatus = 3    -- Global statusline
opt.cmdheight = 0     -- No command line, statusline at bottom
opt.shortmess:append("W")  -- Don't show "written" when saving
opt.shortmess:append("c")  -- Don't show completion messages

-- Hide tab line (use buffers instead, navigate with ←/→)
opt.showtabline = 2

-- Reuse existing buffers when switching (don't open duplicates)
opt.switchbuf = "useopen,usetab"

-- Mouse
opt.mouse = "a"

-- Conceal
opt.conceallevel = 0

-- Disable netrw (using file explorer plugin instead)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

