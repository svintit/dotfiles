-- Autocommands

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- General settings group
local general = augroup("General", { clear = true })


-- Highlight on yank
autocmd("TextYankPost", {
  group = general,
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-- Remove whitespace on save (preserve cursor position)
autocmd("BufWritePre", {
  group = general,
  pattern = "*",
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})

-- Restore cursor position
autocmd("BufReadPost", {
  group = general,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close some filetypes with <q>
autocmd("FileType", {
  group = general,
  pattern = {
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "checkhealth",
    "lazy",
    "mason",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Auto resize splits when window is resized
autocmd("VimResized", {
  group = general,
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- Set filetype specific options
autocmd("FileType", {
  group = general,
  pattern = { "lua", "javascript", "typescript", "typescriptreact", "json", "yaml" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2
  end,
})

-- Python specific settings
autocmd("FileType", {
  group = general,
  pattern = "python",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
  end,
})

-- Auto-reload files when changed externally (e.g., by Claude Code CLI)
local uv = vim.uv or vim.loop
local file_watchers = {}

local function stop_file_watcher(buf)
  local watcher = file_watchers[buf]
  if watcher then
    watcher:stop()
    watcher:close()
    file_watchers[buf] = nil
  end
end

local function start_file_watcher(buf)
  stop_file_watcher(buf)

  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
    return
  end

  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then
    return
  end

  local real_file = uv.fs_realpath(file) or file
  local watcher = uv.new_fs_event()
  if not watcher then
    return
  end

  local ok = watcher:start(real_file, {}, vim.schedule_wrap(function(err)
    if err or not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
      stop_file_watcher(buf)
      return
    end

    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime " .. buf)
    end
  end))

  if not ok then
    watcher:close()
    return
  end

  file_watchers[buf] = watcher
end

autocmd({ "BufReadPost", "BufNewFile", "BufWritePost", "BufEnter" }, {
  group = general,
  callback = function(event)
    start_file_watcher(event.buf)
  end,
})

autocmd({ "BufUnload", "BufDelete", "BufWipeout" }, {
  group = general,
  callback = function(event)
    stop_file_watcher(event.buf)
  end,
})

autocmd({ "FocusGained", "CursorHold", "CursorHoldI" }, {
  group = general,
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
})

for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) then
    start_file_watcher(buf)
  end
end

-- Autosave on focus lost or buffer leave
autocmd({ "FocusLost", "BufLeave" }, {
  group = general,
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].modified and vim.bo[buf].buftype == "" and vim.fn.expand("%") ~= "" then
      vim.cmd("silent! write")
    end
  end,
})

-- Auto-clear "Copied:" messages on cursor movement
autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = general,
  callback = function()
    local msg = vim.fn.execute("messages"):match("Copied:")
    if msg then
      vim.cmd('echo ""')
    end
  end,
})

-- Smart scrolloff - centered cursor but no empty space at file boundaries
local function adjust_scrolloff()
  if vim.bo.buftype == "terminal" then
    return
  end

  local buf_lines = vim.api.nvim_buf_line_count(0)
  local cursor_line = vim.fn.line(".")
  local win_height = vim.api.nvim_win_get_height(0)

  -- If cursor is in the last 8 lines and would cause empty space, disable scrolloff
  if cursor_line > buf_lines - 8 and buf_lines > win_height then
    vim.opt_local.scrolloff = 0
  else
    vim.opt_local.scrolloff = 8
  end
end

autocmd({ "CursorMoved", "CursorMovedI", "BufEnter", "WinEnter", "WinScrolled" }, {
  group = general,
  callback = adjust_scrolloff,
})


-- Smart horizontal scroll - only allow if content extends past visible area
local function has_long_lines()
  local win_width = vim.api.nvim_win_get_width(0) - vim.fn.getwininfo(vim.fn.win_getid())[1].textoff
  local top = vim.fn.line("w0")
  local bot = vim.fn.line("w$")
  for lnum = top, bot do
    local line = vim.fn.getline(lnum)
    if vim.fn.strdisplaywidth(line) > win_width then
      return true
    end
  end
  return false
end

local function smart_scroll_right()
  if has_long_lines() then
    return "zl"
  end
  return ""
end

local function smart_scroll_left()
  if vim.fn.winsaveview().leftcol > 0 then
    return "zh"
  end
  return ""
end

vim.keymap.set("n", "zl", smart_scroll_right, { expr = true })
vim.keymap.set("n", "zh", smart_scroll_left, { expr = true })
vim.keymap.set("n", "zL", function()
  if has_long_lines() then
    vim.cmd("normal! zL")
  end
end)
vim.keymap.set("n", "zH", function()
  if vim.fn.winsaveview().leftcol > 0 then
    vim.cmd("normal! zH")
  end
end)
vim.keymap.set({ "n", "i" }, "<ScrollWheelLeft>", function()
  if vim.bo.buftype ~= "terminal" and vim.fn.winsaveview().leftcol > 0 then
    vim.cmd("normal! 3zh")
  end
end)
vim.keymap.set({ "n", "i" }, "<ScrollWheelRight>", function()
  if vim.bo.buftype ~= "terminal" and has_long_lines() then
    vim.cmd("normal! 3zl")
  end
end)

local function can_scroll_down()
  if vim.bo.buftype == "terminal" then
    return true
  end
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local buf_lines = vim.api.nvim_buf_line_count(buf)
  local win_height = vim.api.nvim_win_get_height(win)
  local top_line = vim.fn.line("w0")
  return top_line + win_height - 1 < buf_lines
end

vim.keymap.set({ "n", "i" }, "<ScrollWheelDown>", function()
  if vim.bo.buftype ~= "terminal" then
    if can_scroll_down() then
      local key = vim.api.nvim_replace_termcodes("<C-e><C-e><C-e>", true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
    end
  end
end)

vim.keymap.set({ "n", "i" }, "<ScrollWheelUp>", function()
  if vim.bo.buftype ~= "terminal" then
    local view = vim.fn.winsaveview()
    if view.topline > 1 then
      local key = vim.api.nvim_replace_termcodes("<C-y><C-y><C-y>", true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
    end
  end
end)

vim.keymap.set("n", "<C-d>", function()
  if vim.bo.buftype ~= "terminal" then
    if can_scroll_down() then
      local key = vim.api.nvim_replace_termcodes("<C-d>", true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
    end
  end
end)

vim.keymap.set("n", "<C-f>", function()
  if vim.bo.buftype ~= "terminal" then
    if can_scroll_down() then
      local key = vim.api.nvim_replace_termcodes("<C-f>", true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
    end
  end
end)

-- Terminal buffer settings
autocmd("TermOpen", {
  group = general,
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    vim.opt_local.scrolloff = 0
    vim.opt_local.sidescrolloff = 0
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"

    local function scroll_down_limited()
      local win = vim.api.nvim_get_current_win()
      local buf_lines = vim.api.nvim_buf_line_count(buf)
      local win_height = vim.api.nvim_win_get_height(win)
      local top_line = vim.fn.line("w0")
      if top_line + win_height <= buf_lines then
        return "<C-e><C-e><C-e>"
      end
      return ""
    end

    local function scroll_up()
      local view = vim.fn.winsaveview()
      if view.topline > 1 then
        view.topline = math.max(1, view.topline - 3)
        vim.fn.winrestview(view)
      end
    end

    local function scroll_down()
      local win = vim.api.nvim_get_current_win()
      local buf_lines = vim.api.nvim_buf_line_count(buf)
      local win_height = vim.api.nvim_win_get_height(win)
      local view = vim.fn.winsaveview()
      if view.topline + win_height <= buf_lines then
        view.topline = view.topline + 3
        vim.fn.winrestview(view)
      end
    end

    local modes = { "n", "t", "i" }
    for _, mode in ipairs(modes) do
      vim.keymap.set(mode, "<ScrollWheelLeft>", "<Nop>", { buffer = buf })
      vim.keymap.set(mode, "<ScrollWheelRight>", "<Nop>", { buffer = buf })
      vim.keymap.set(mode, "<S-ScrollWheelLeft>", "<Nop>", { buffer = buf })
      vim.keymap.set(mode, "<S-ScrollWheelRight>", "<Nop>", { buffer = buf })
      vim.keymap.set(mode, "<C-ScrollWheelLeft>", "<Nop>", { buffer = buf })
      vim.keymap.set(mode, "<C-ScrollWheelRight>", "<Nop>", { buffer = buf })
      vim.keymap.set(mode, "<ScrollWheelDown>", scroll_down, { buffer = buf })
      vim.keymap.set(mode, "<ScrollWheelUp>", scroll_up, { buffer = buf })
    end
    vim.keymap.set("n", "zl", "<Nop>", { buffer = buf })
    vim.keymap.set("n", "zh", "<Nop>", { buffer = buf })
    vim.keymap.set("n", "zL", "<Nop>", { buffer = buf })
    vim.keymap.set("n", "zH", "<Nop>", { buffer = buf })
  end,
})

-- Auto-insert mode when focusing terminal buffers (for Claude Code)
-- DISABLED: Prevents scrolling in terminal buffers
-- autocmd({ "BufEnter", "WinEnter", "TermEnter", "FocusGained" }, {
--   group = general,
--   callback = function()
--     if vim.bo.buftype == "terminal" and vim.fn.mode() ~= "t" then
--       local job_id = vim.b.terminal_job_id
--       if job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1 then
--         vim.cmd("startinsert")
--       end
--     end
--   end,
-- })

-- Handle mouse clicks in terminal - force insert mode
-- DISABLED: Prevents scrolling in terminal buffers
-- autocmd("CursorMoved", {
--   group = general,
--   callback = function()
--     if vim.bo.buftype == "terminal" and vim.fn.mode() == "n" then
--       local job_id = vim.b.terminal_job_id
--       if job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1 then
--         vim.schedule(function()
--           vim.cmd("startinsert")
--         end)
--       end
--     end
--   end,
-- })

-- Track when leaving terminal
local left_terminal = false
autocmd("BufLeave", {
  group = general,
  callback = function()
    if vim.bo.buftype == "terminal" then
      left_terminal = true
    end
  end,
})

-- Return to normal mode when entering code buffer from terminal
autocmd("BufEnter", {
  group = general,
  callback = function()
    if left_terminal and vim.bo.buftype == "" then
      vim.schedule(function()
        vim.cmd("stopinsert")
      end)
    end
    left_terminal = false
  end,
})

-- Focus follows mouse - switch window on mouse click
vim.keymap.set("", "<LeftMouse>", function()
  local mouse_pos = vim.fn.getmousepos()
  if mouse_pos.winid ~= 0 and mouse_pos.winid ~= vim.api.nvim_get_current_win() then
    pcall(vim.api.nvim_set_current_win, mouse_pos.winid)
  end
  return "<LeftMouse>"
end, { expr = true })

-- Smart buffer close - show dashboard instead of quitting on last buffer
local function smart_close()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  local current_buf = vim.api.nvim_get_current_buf()
  local wins = vim.api.nvim_tabpage_list_wins(0)

  -- Count actual splits (not floating windows)
  local normal_wins = 0
  for _, win in ipairs(wins) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative == "" then
      normal_wins = normal_wins + 1
    end
  end

  if normal_wins > 1 then
    -- Multiple splits - just close the current window
    vim.cmd("close")
  elseif #bufs <= 1 then
    -- Only one split and one buffer - show dashboard
    vim.cmd("Alpha")
  else
    -- Only one split but multiple buffers - delete buffer
    if vim.bo[current_buf].modified then
      vim.ui.select({ "Save and close", "Discard changes", "Cancel" }, { prompt = "Buffer has unsaved changes:" }, function(choice)
        if choice == "Save and close" then
          vim.cmd("write")
          vim.cmd("bdelete " .. current_buf)
        elseif choice == "Discard changes" then
          vim.cmd("bdelete! " .. current_buf)
        end
      end)
    else
      vim.cmd("bdelete " .. current_buf)
    end
  end
end

vim.keymap.set("n", "Q", smart_close, { desc = "Smart close buffer" })
vim.keymap.set("n", "<D-w>", smart_close, { desc = "Smart close buffer" })
