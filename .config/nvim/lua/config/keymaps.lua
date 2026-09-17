-- Keymaps Configuration
-- Preserving your existing bindings + modern additions

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Disable cmd+enter
keymap({ "n", "i", "v", "t" }, "<D-CR>", "<Nop>", { noremap = true, silent = true, desc = "Disabled" })

-- Leader key is set in init.lua before lazy.nvim loads

-- gt{number}u to jump up N lines
keymap("n", "gtu", function()
  local count = vim.v.count1
  vim.cmd("normal! " .. count .. "k")
end, { noremap = true, silent = true, desc = "Go up N lines" })

-- ============================================
-- YOUR ORIGINAL KEYBINDINGS (preserved)
-- ============================================

-- jj to escape (insert mode)
keymap("i", "jj", "<Esc>", opts)

-- Shift+W to save
keymap("n", "W", ":w<CR>", opts)

-- Shift+Q to quit
keymap("n", "<S-q>", ":q<CR>", opts)

-- r to redo (u undoes, r redoes)
keymap("n", "r", "<C-r>", opts)

-- Macro recording safety: require `qq` to start recording
-- Keep single `q` working only to stop an active recording
keymap("n", "q", function()
  if vim.fn.reg_recording() ~= "" then
    return "q"
  end

  return ""
end, { expr = true, noremap = true, silent = true, nowait = true, desc = "Stop recording (or no-op)" })
keymap("n", "qq", "q", { noremap = true, silent = true, desc = "Start macro recording" })

-- Alt+Arrow: word movement
-- Ghostty sends a distinct Alt+Right keycode, so map special key not raw Esc bytes
keymap("n", "<M-b>", "b", opts)
keymap("i", "<M-b>", "<C-Left>", opts)
keymap("n", "<M-Right>", "w", opts)
keymap("i", "<M-Right>", "<C-Right>", opts)

-- ============================================
-- MODERN ADDITIONS
-- ============================================

-- Window navigation handled by smart-splits.nvim (Ctrl+hjkl)
-- Window resizing handled by smart-splits.nvim (Alt+hjkl)

-- Resize windows with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Move text up and down in visual mode
keymap("v", "J", ":m '>+1<CR>gv=gv", opts)
keymap("v", "K", ":m '<-2<CR>gv=gv", opts)

-- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Keep cursor centered when navigating with arrow keys (miryoku nav layer)
keymap("n", "<Up>", "kzz", opts)
keymap("n", "<Down>", "jzz", opts)
keymap("n", "<C-d>", "<C-d>zz", opts)
keymap("n", "<C-u>", "<C-u>zz", opts)
keymap("n", "n", "nzzzv", opts)
keymap("n", "N", "Nzzzv", opts)
keymap("n", "G", "Gzz", opts)
keymap("n", "gg", "ggzz", opts)
keymap("n", "{", "{zz", opts)
keymap("n", "}", "}zz", opts)

-- Better paste (don't overwrite register)
keymap("v", "p", '"_dP', opts)

-- Clear search highlights
keymap("n", "<Esc>", ":noh<CR>", opts)

-- Fold toggle (imports, code blocks, etc.)
keymap("n", "<Space><Space>", "za", { noremap = true, silent = true, desc = "Toggle fold" })

-- Quick fix navigation
keymap("n", "]q", ":cnext<CR>", opts)
keymap("n", "[q", ":cprev<CR>", opts)

-- Diagnostic navigation
keymap("n", "]d", vim.diagnostic.goto_next, opts)
keymap("n", "[d", vim.diagnostic.goto_prev, opts)
keymap("n", "<leader>d", vim.diagnostic.open_float, opts)

-- Ctrl+Click to go to definition (like VS Code)
vim.keymap.set("n", "<C-LeftMouse>", "<LeftMouse><Cmd>lua vim.lsp.buf.definition()<CR>", { noremap = true, silent = true, desc = "Go to definition" })

-- ============================================
-- LEADER KEY MAPPINGS
-- ============================================

-- File explorer (nvim-tree) - keymaps set in plugins/init.lua
-- te toggles tree, - reveals current file

-- Fuzzy finding keymaps are set in snacks picker config

-- Git pickers via snacks
keymap("n", "gs", function() require("snacks").picker.git_status() end, opts)
keymap("n", "<leader>gs", function() require("snacks").picker.git_status() end, opts)
keymap("n", "gc", function() require("snacks").picker.git_log() end, opts)
keymap("n", "gb", function() require("snacks").picker.git_branches() end, opts)

-- Buffer management
keymap("n", "<leader>bd", ":bdelete<CR>", opts)
keymap("n", "<leader>bn", ":bnext<CR>", opts)
keymap("n", "<leader>bp", ":bprev<CR>", opts)

-- Split management
keymap("n", "<leader>sv", ":vsplit<CR>", opts)
keymap("n", "<leader>sh", ":split<CR>", opts)
keymap("n", "<leader>se", "<C-w>=", opts)
keymap("n", "<leader>sx", ":close<CR>", opts)
keymap("n", [[\\]], ":vsplit<CR>", opts)
keymap("n", [[--]], ":split<CR>", opts)
keymap("n", "<A-\\>", ":vsplit<CR>", opts)
keymap("n", "<A-->", ":split<CR>", opts)

-- Lazy plugin manager
keymap("n", "<leader>l", ":Lazy<CR>", opts)

-- Format
keymap("n", "<leader>fm", function()
  vim.lsp.buf.format({ async = true })
end, opts)

-- ============================================
-- CLIPBOARD (Cmd+C/V/X for macOS)
-- ============================================

-- Cmd+C to copy
keymap("v", "<D-c>", '"+y', opts)
keymap("n", "<D-c>", '"+yy', opts)

-- Cmd+V to paste
keymap("n", "<D-v>", '"+p', opts)
keymap("v", "<D-v>", '"+p', opts)
keymap("i", "<D-v>", '<C-r>+', opts)
keymap("c", "<D-v>", '<C-r>+', opts)

-- Cmd+X to cut
keymap("v", "<D-x>", '"+d', opts)

-- Cmd+A to select all
keymap("n", "<D-a>", "ggVG", opts)

-- Cmd+S to save
keymap("n", "<D-s>", ":w<CR>", opts)
keymap("i", "<D-s>", "<Esc>:w<CR>a", opts)

-- ============================================
-- TERMINAL INTEGRATION
-- ============================================

-- Efficient nvim-tree toggle with current-file focus
local function toggle_nvim_tree_find_file()
  local api = require("nvim-tree.api")

  if api.tree.is_visible() then
    api.tree.close()
    return
  end

  local file_path = vim.fn.expand("%:p")
  if file_path == "" or vim.fn.filereadable(file_path) == 0 then
    api.tree.toggle({ focus = true })
    return
  end

  api.tree.find_file({ open = true, focus = true })
end

keymap("n", "t", toggle_nvim_tree_find_file, { noremap = true, silent = true, nowait = true, desc = "Toggle file tree (focus current file)" })

-- ============================================
-- FILE PATH OPERATIONS
-- ============================================

-- Copy relative path (both cp and cr)
local function copy_relative_path()
  local path = vim.fn.expand("%")
  vim.fn.setreg("+", path)
  vim.notify("💾 Copied relative path", vim.log.levels.INFO)
end

keymap("n", "cp", copy_relative_path, { noremap = true, silent = true, desc = "Copy relative path" })
keymap("n", "cr", copy_relative_path, { noremap = true, silent = true, desc = "Copy relative path" })

-- Copy GitHub URL
keymap("n", "cg", function()
  local line = vim.fn.line(".")

  -- Get git remote URL
  local remote = vim.fn.system("git config --get remote.origin.url"):gsub("%s+", "")
  if vim.v.shell_error ~= 0 then
    vim.notify("Not a git repository", vim.log.levels.ERROR)
    return
  end

  -- Parse GitHub URL from git remote
  local github_url = remote:gsub("^git@github%.com:", "https://github.com/")
                          :gsub("^https://github%.com/", "https://github.com/")
                          :gsub("%.git$", "")

  -- Get current branch, fall back to main
  local branch = vim.fn.system("git rev-parse --abbrev-ref HEAD"):gsub("%s+", "")
  if vim.v.shell_error ~= 0 or branch == "" then
    branch = "main"
  end

  -- Get path relative to git root
  local git_root = vim.fn.system("git rev-parse --show-toplevel"):gsub("%s+", "")
  local full_path = vim.fn.expand("%:p")
  local path = full_path:gsub("^" .. git_root:gsub("([%-%.%[%]%(%)%+%*%?%^%$])", "%%%1") .. "/", "")

  -- Construct GitHub file URL with line number
  local url = string.format("%s/blob/%s/%s#L%d", github_url, branch, path, line)

  vim.fn.setreg("+", url)
  vim.notify("💾 Copied GitHub URL", vim.log.levels.INFO)
end, { noremap = true, silent = true, desc = "Copy GitHub URL" })
