-- Neovim Configuration
-- Modernized setup with lazy.nvim

-- Set leader key BEFORE loading lazy.nvim
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load core options first
require("config.options")

-- Bootstrap lazy.nvim
require("config.lazy")

-- Load keymaps and autocmds after plugins
require("config.keymaps")
require("config.autocmds")
