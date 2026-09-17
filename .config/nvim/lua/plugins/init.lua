-- Plugin specifications for lazy.nvim

return {
  -- ============================================
  -- COLORSCHEME
  -- ============================================
  {
    "oskarnurm/koda.nvim",
    name = "koda",
    lazy = false,
    priority = 1000,
    config = function()
      local bg = "#0a0c14"

      local function apply_custom_highlights()
        local set = vim.api.nvim_set_hl
        local bg_num = tonumber("0A0C14", 16)
        local subtle_white = tonumber("E0E0E0", 16)

        local function set_bg_preserve(group)
          local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
          if ok and hl and next(hl) ~= nil then
            hl.bg = bg_num
            vim.api.nvim_set_hl(0, group, hl)
          else
            vim.api.nvim_set_hl(0, group, { bg = bg_num })
          end
        end

        for _, group in ipairs({
          "SignColumn",
          "EndOfBuffer",
          "NvimTreeNormal",
          "NvimTreeNormalNC",
          "NeoTreeNormal",
          "NeoTreeNormalNC",
        }) do
          set_bg_preserve(group)
        end

        -- Set explicit neutral default text color so terminal fg does not leak in
        for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat" }) do
          local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
          if ok and hl and next(hl) ~= nil then
            hl.bg = bg_num
            hl.fg = subtle_white
            vim.api.nvim_set_hl(0, group, hl)
          else
            vim.api.nvim_set_hl(0, group, { bg = bg_num, fg = subtle_white })
          end
        end

        -- Tree-only custom colors
        local tree_inactive_file = tonumber("B0B0B0", 16)
        local tree_inactive_folder = tonumber("777777", 16)
        local tree_active = tonumber("FFFFFF", 16)

        set(0, "NvimTreeFolderIcon", { fg = tree_inactive_folder })
        set(0, "NvimTreeFolderName", { fg = tree_inactive_folder, bold = false })
        set(0, "NvimTreeEmptyFolderName", { fg = tree_inactive_folder, bold = false })
        set(0, "NvimTreeOpenedFolderName", { fg = tree_active, bold = true })
        set(0, "NvimTreeOpenedFolderIcon", { fg = tree_active })
        set(0, "NvimTreeFileName", { fg = tree_inactive_file })
        set(0, "NvimTreeOpenedFile", { fg = tree_active, bold = true })

        -- Keep tree/code divider hidden
        set(0, "NvimTreeWinSeparator", { fg = bg, bg = bg })
        set(0, "NvimTreeVertSplit", { fg = bg, bg = bg })

        -- Snacks picker/search: keep neutral koda-like tones (no lavender)
        local snacks_primary = subtle_white
        local snacks_muted = tonumber("A0A0A0", 16)
        set(0, "SnacksPickerFile", { fg = snacks_primary })
        set(0, "SnacksPickerDir", { fg = snacks_muted })
        set(0, "SnacksPickerDirectory", { fg = snacks_primary })
        set(0, "SnacksPickerPrompt", { fg = snacks_primary })
        set(0, "SnacksInputPrompt", { fg = snacks_muted })
        set(0, "SnacksInputTitle", { fg = snacks_primary, bold = true })
      end

      local function replace_lavender_with_subtle_white()
        local target = 12892392
        local replacement = tonumber("E0E0E0", 16)

        for _, group in ipairs(vim.fn.getcompletion("", "highlight")) do
          local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
          if ok and hl then
            local changed = false
            if hl.fg == target then
              hl.fg = replacement
              changed = true
            end
            if hl.bg == target then
              hl.bg = replacement
              changed = true
            end
            if hl.sp == target then
              hl.sp = replacement
              changed = true
            end
            if changed then
              vim.api.nvim_set_hl(0, group, hl)
            end
          end
        end
      end

      local function enforce_keyword_red()
        local keyword_red = tonumber("FF7676", 16)
        local set = vim.api.nvim_set_hl

        -- Base keyword captures (keep narrow; don't tint identifiers/types like Props)
        for _, group in ipairs({
          "@keyword",
          "@keyword.function",
          "@keyword.type",
          "@keyword.class",
          "@keyword.operator",
          "@keyword.modifier",
          "@keyword.declaration",
          "@keyword.storage",
        }) do
          set(0, group, { fg = keyword_red })
        end

        -- LSP semantic token keyword groups (exclude returns)
        for _, group in ipairs(vim.fn.getcompletion("", "highlight")) do
          if group:match("^@lsp.*keyword") and not group:match("return") then
            local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
            if ok and hl then
              hl.fg = keyword_red
              hl.link = nil
              set(0, group, hl)
            else
              set(0, group, { fg = keyword_red })
            end
          end
        end
      end

      local function disable_italics()
        for _, group in ipairs(vim.fn.getcompletion("", "highlight")) do
          local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
          if ok and hl and hl.italic then
            hl.italic = false
            vim.api.nvim_set_hl(0, group, hl)
          end
        end
      end

      require("koda").setup({
        transparent = false,
        styles = {
          functions = {},
          keywords = {},
          comments = {},
          strings = {},
          constants = {},
        },
        on_highlights = function(hl, _)
          -- Keep keyword tint narrow so identifiers/types (e.g. Props) stay default koda
          hl["@keyword"] = { fg = "#FF7676" }
          hl["@keyword.function"] = { fg = "#FF7676" }
          hl["@keyword.type"] = { fg = "#FF7676" }
          hl["@keyword.class"] = { fg = "#FF7676" }
          hl["@keyword.operator"] = { fg = "#FF7676" }
          hl["@keyword.modifier"] = { fg = "#FF7676" }
          hl["@keyword.declaration"] = { fg = "#FF7676" }
          hl["@keyword.storage"] = { fg = "#FF7676" }
        end,
      })

      vim.cmd("colorscheme koda-dark")
      apply_custom_highlights()
      enforce_keyword_red()
      replace_lavender_with_subtle_white()
      disable_italics()

      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          apply_custom_highlights()
          enforce_keyword_red()
          replace_lavender_with_subtle_white()
          disable_italics()
        end,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function()
          enforce_keyword_red()
        end,
      })
    end,
  },

  -- ============================================
  -- FOLDING (auto-collapse imports)
  -- ============================================
  {
    "kevinhwang91/nvim-ufo",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "kevinhwang91/promise-async" },
    config = function()
      vim.o.foldcolumn = "0"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true

      require("ufo").setup({
        provider_selector = function(_, _, _)
          return { "lsp", "indent" }
        end,
        close_fold_kinds_for_ft = {
          default = {},
          typescript = { "imports" },
          typescriptreact = { "imports" },
          javascript = { "imports" },
          javascriptreact = { "imports" },
        },
      })
    end,
  },

  -- ============================================
  -- TAB BAR
  -- ============================================
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
    config = function()
      vim.api.nvim_set_hl(0, "TabLineFill", { bg = "#0a0c14" })

      -- Thin padding line below tab bar (winbar styled as empty space)
      vim.api.nvim_set_hl(0, "WinBarPad", { bg = "#0a0c14", fg = "#141420" })
      vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "BufEnter" }, {
        callback = function()
          local win = vim.api.nvim_get_current_win()
          local config = vim.api.nvim_win_get_config(win)
          if config.relative ~= "" then return end
          local bt = vim.bo.buftype
          if bt == "nofile" or bt == "terminal" or bt == "prompt" or bt == "quickfix" then return end
          vim.wo[win].winbar = "%#WinBarPad#" .. string.rep("▁", 300)
        end,
      })

      require("bufferline").setup({
        options = {
          mode = "buffers",
          themable = true,
          show_buffer_close_icons = false,
          show_close_icon = false,
          show_buffer_icons = true,
          separator_style = { "", "" },
          indicator = {
            style = "none",
          },
          tab_size = 0,
          max_name_length = 999,
          truncate_names = true,
          name_formatter = function(buf)
            return " " .. buf.name
          end,
          diagnostics = false,
          offsets = {
            {
              filetype = "NvimTree",
              text = "",
              separator = false,
            },
          },

        },
        highlights = {
          fill = { bg = "#0a0c14" },
          background = { bg = "#0a0c14", fg = "#E0E0E0" },
          buffer_selected = { bg = "#0a0c14", fg = "#ECECEC", bold = true, italic = false },
          buffer_visible = { bg = "#0a0c14", fg = "#E0E0E0" },
          separator = { bg = "#0a0c14", fg = "#1a1a2a" },
          separator_selected = { bg = "#0a0c14", fg = "#1a1a2a" },
          separator_visible = { bg = "#0a0c14", fg = "#1a1a2a" },
          modified = { bg = "#0a0c14", fg = "#e5c07b" },
          modified_selected = { bg = "#0a0c14", fg = "#e5c07b" },
          modified_visible = { bg = "#0a0c14", fg = "#5c5c7a" },
          duplicate = { bg = "#0a0c14", fg = "#E0E0E0", italic = false },
          duplicate_selected = { bg = "#0a0c14", fg = "#ECECEC", italic = false },
          duplicate_visible = { bg = "#0a0c14", fg = "#E0E0E0", italic = false },
        },
      })
    end,
  },

  -- ============================================
  -- SMART SPLITS
  -- ============================================
  {
    "mrjones2014/smart-splits.nvim",
    lazy = false,
    config = function()
      require("smart-splits").setup({
        at_edge = "stop",
        multiplexer_integration = nil,
      })
      local ss = require("smart-splits")
      -- Navigation (Ctrl + hjkl) - works in normal and terminal mode
      vim.keymap.set({ "n", "t" }, "<A-h>", ss.move_cursor_left)
      vim.keymap.set({ "n", "t" }, "<A-j>", ss.move_cursor_down)
      vim.keymap.set({ "n", "t" }, "<A-k>", ss.move_cursor_up)
      vim.keymap.set({ "n", "t" }, "<A-l>", ss.move_cursor_right)
      -- Creating splits (Alt + \ and Alt + -)
      vim.keymap.set({ "n", "t" }, "<M-\\>", "<cmd>vsplit<cr>")
      vim.keymap.set({ "n", "t" }, "<M-->", "<cmd>split<cr>")
    end,
  },

  -- ============================================
  -- UI ENHANCEMENTS
  -- ============================================

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local function lsp_name()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients == 0 then return "" end
        local names = {}
        for _, client in ipairs(clients) do
          if client.name ~= "copilot" then
            table.insert(names, client.name)
          end
        end
        if #names == 0 then return "" end
        return " " .. table.concat(names, ", ")
      end

      local function macro_recording()
        local ok, recorder = pcall(require, "recorder")
        if ok then
          local status = recorder.recordingStatus()
          if status ~= "" then return "󰑋 " .. status end
        end
        local reg = vim.fn.reg_recording()
        if reg == "" then return "" end
        return "󰑋 @" .. reg
      end

      local function search_count()
        if vim.v.hlsearch == 0 then return "" end
        local ok, result = pcall(vim.fn.searchcount, { maxcount = 999 })
        if not ok or result.total == 0 then return "" end
        return string.format(" %d/%d", result.current, result.total)
      end

      local function git_branch()
        local branch = vim.b.gitsigns_head
        if branch and branch ~= "" and branch ~= ".invalid" then return branch end
        local handle = io.popen("git -C " .. vim.fn.expand("%:p:h") .. " branch --show-current 2>/dev/null")
        if handle then
          branch = handle:read("*l")
          handle:close()
          return branch or ""
        end
        return ""
      end

      -- Use built-in auto theme (works across colorschemes like koda)
      local lualine_theme = "auto"

      require("lualine").setup({
        options = {
          theme = lualine_theme,
          component_separators = { left = "│", right = "│" },
          section_separators = { left = "", right = "" },
          globalstatus = true,
          refresh = {
            statusline = 50,
            tabline = 100,
            winbar = 50,
            refresh_time = 16,
            events = {
              "WinEnter",
              "BufEnter",
              "BufWritePost",
              "SessionLoadPost",
              "FileChangedShellPost",
              "VimResized",
              "Filetype",
              "CursorMoved",
              "CursorMovedI",
              "ModeChanged",
            },
          },
        },
        sections = {
          lualine_a = {
            { "mode" },
          },
          lualine_b = {
            {
              git_branch,
              icon = "",
            },
            {
              "diff",
              colored = true,
              symbols = { added = " ", modified = " ", removed = " " },
              cond = function() return vim.b.gitsigns_head ~= nil end,
            },
          },
          lualine_c = {
            { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 }, color = { bg = "#0A0D16" } },
            {
              function()
                local bufname = vim.api.nvim_buf_get_name(0)
                if vim.bo.buftype == "terminal" then
                  if bufname:match("claude") then return "Claude" end
                  return "Terminal"
                end
                local filename = vim.fn.expand("%:t")
                if filename == "" then return "[No Name]" end
                local modified = vim.bo.modified and " ●" or ""
                local readonly = vim.bo.readonly and " " or ""
                local result = filename .. modified .. readonly

                -- Append dimmed path only if it fits
                local dir = vim.fn.expand("%:~:.:h")
                if dir ~= "" and dir ~= "." then
                  -- Reserve ~60% of window for non-c sections (mode, branch, diagnostics, position, etc.)
                  local available = vim.fn.winwidth(0) - math.floor(vim.fn.winwidth(0) * 0.6) - #result - 4
                  if available > 20 then
                    if #dir > available then
                      dir = "…" .. dir:sub(-(available - 1))
                    end
                    result = result .. "  %#lualine_c_filePath#" .. dir .. "%*"
                  end
                end

                return result
              end,
              separator = "",
              color = { bg = "#0A0D16" },
            },
            { macro_recording, color = { fg = "#eb6f92", bg = "#0A0D16" } },
            { search_count, color = { fg = "#c4a7e7", bg = "#0A0D16" } },
          },
          lualine_x = {
            {
              "diagnostics",
              symbols = { error = " ", warn = " ", info = " ", hint = "󰌵 " },
              colored = true,
              color = { bg = "#0A0D16" },
            },
            { lsp_name, color = { fg = "#9ccfd8", bg = "#0A0D16" } },
          },
          lualine_y = {
            {
              "encoding",
              cond = function() return vim.bo.fileencoding ~= "utf-8" end,
            },
            {
              "fileformat",
              cond = function() return vim.bo.fileformat ~= "unix" end,
              symbols = { unix = "", dos = "󰨡", mac = "" },
            },
            { "filetype", icons_enabled = false },
          },
          lualine_z = {
            { "progress" },
            { "location", padding = { left = 0, right = 1 } },
          },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
      })

      -- Keep the center fill between C and X sections on the same dark bg.
      local middle_bg = tonumber("0A0D16", 16)
      local function set_lualine_bg(group)
        local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
        if ok and hl and next(hl) ~= nil then
          hl.bg = middle_bg
          hl.link = nil
          vim.api.nvim_set_hl(0, group, hl)
        else
          vim.api.nvim_set_hl(0, group, { bg = middle_bg })
        end
      end

      for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal", "inactive" }) do
        set_lualine_bg("lualine_c_" .. mode)
        set_lualine_bg("lualine_x_" .. mode)
        set_lualine_bg("lualine_transitional_lualine_b_to_lualine_c_" .. mode)
        set_lualine_bg("lualine_transitional_lualine_c_to_lualine_x_" .. mode)
      end
    end,
  },

  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup({
        on_attach = function(bufnr)
          local api = require("nvim-tree.api")
          api.config.mappings.default_on_attach(bufnr)

          vim.opt_local.wrap = false
          vim.opt_local.sidescroll = 1
          vim.opt_local.sidescrolloff = 0

          local function align_cursor_node_left()
            local line = vim.api.nvim_get_current_line()
            local win_width = vim.api.nvim_win_get_width(0)
            if vim.fn.strdisplaywidth(line) > win_width then
              vim.cmd("normal! zs")
            else
              vim.cmd("normal! 0")
            end
          end

          vim.api.nvim_create_autocmd({ "BufEnter", "CursorMoved" }, {
            buffer = bufnr,
            callback = align_cursor_node_left,
          })

          align_cursor_node_left()
        end,
        hijack_cursor = true,
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        sort_by = "name",
        view = {
          width = 50,
          preserve_window_proportions = true,
        },
        renderer = {
          group_empty = true,
          highlight_git = false,
          indent_width = 1,
          icons = {
            padding = {
              icon = "  ",
              folder_arrow = " ",
            },
            show = {
              git = false,
              diagnostics = false,
            },
          },
        },
        filters = {
          dotfiles = false,
          git_ignored = true,
          custom = {
            "^%.git$",
            "^node_modules$",
            "^__pycache__$",
            "^dist$",
            "^build$",
            "^%.next$",
            "^%.turbo$",
            "^%.cache$",
            "^coverage$",
            "^tmp$",
          },
        },
        git = {
          enable = false,
          ignore = false,
        },
        diagnostics = {
          enable = false,
        },
        update_focused_file = {
          enable = true,
          update_root = false,
        },
        filesystem_watchers = {
          enable = true,
          debounce_delay = 150,
        },
      })

      vim.keymap.set("n", "te", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file explorer" })


      -- Restart Neovim (save all and quit - terminal will keep session)
      vim.keymap.set("n", "<F5>", "<cmd>wa | qa<cr>", { desc = "Save all and quit (restart)" })

    end,
  },


  -- Icons
  {
    "nvim-tree/nvim-web-devicons",
    lazy = false,
    opts = {
      default = true,
      color_icons = true,
    },
  },

  -- Indent guides
  {
    "shellRaining/hlchunk.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("hlchunk").setup({
        chunk = {
          enable = true,
          -- chunk only supports one (or normal+error) color; keep it on your accent
          style = "#FF7676",
          delay = 50,
          use_treesitter = true,
          chars = {
            horizontal_line = "─",
            vertical_line = "│",
            left_top = "╭",
            left_bottom = "╰",
            right_arrow = "─",
          },
        },
        indent = {
          enable = false,
        },
        line_num = {
          enable = false,
        },
        blank = {
          enable = false,
        },
      })
    end,
  },

  -- Rainbow delimiters (replacing rainbow plugin)
  {
    "HiPhish/rainbow-delimiters.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = "BufReadPost",
    config = function()
      local rainbow_delimiters = require("rainbow-delimiters")
      require("rainbow-delimiters.setup").setup({
        strategy = {
          [""] = rainbow_delimiters.strategy["global"],
          vim = rainbow_delimiters.strategy["local"],
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        highlight = {
          "RainbowDelimiterYellow",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
          "RainbowDelimiterRed",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
        },
      })
    end,
  },

  -- Better notifications
  {
    "rcarriga/nvim-notify",
    lazy = false,
    config = function()
      local notify = require("notify")
      notify.setup({
        stages = "fade",
        timeout = 2500,
        fps = 60,
        render = "wrapped-compact",
        max_width = 50,
        max_height = 10,
        top_down = false,
        background_colour = "#0a0c14",
        on_open = function(win)
          vim.api.nvim_win_set_config(win, { border = "rounded" })
        end,
        icons = {
          ERROR = "",
          WARN = "",
          INFO = "",
          DEBUG = "",
          TRACE = "",
        },
      })
      vim.notify = notify
    end,
  },

  -- Route vim messages through noice
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    opts = {
      cmdline = {
        enabled = false,
      },
      messages = {
        enabled = false,
      },
      views = {
        cmdline_popup = {
          position = {
            row = 5,
            col = "50%",
          },
          size = {
            width = 60,
            height = "auto",
          },
        },
        popupmenu = {
          relative = "editor",
          position = {
            row = 8,
            col = "50%",
          },
          size = {
            width = 60,
            height = 10,
          },
          border = {
            style = "rounded",
            padding = { 0, 1 },
          },
          win_options = {
            winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
          },
        },
      },
      routes = {
        { filter = { event = "msg_show", kind = "", find = "written" }, opts = { skip = true } },
        { filter = { event = "msg_show", kind = "", find = "Written" }, opts = { skip = true } },
        { filter = { event = "msg_show", kind = "", find = "%d+L, %d+B" }, opts = { skip = true } },
        { filter = { event = "msg_show", find = "^/" }, opts = { skip = true } },
        { filter = { event = "msg_showmode" }, opts = { skip = true } },
        -- Force ALL messages to notify, never split
        { filter = { event = "msg_show" }, view = "notify" },
        { filter = { event = "msg_history" }, view = "notify" },
      },
      popupmenu = {
        enabled = false,
      },
      notify = {
        enabled = true,
        view = "notify",
      },
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        progress = {
          enabled = false,
        },
        hover = {
          enabled = false,
        },
        signature = {
          enabled = false,
        },
      },
      presets = {
        bottom_search = false,
        command_palette = false,
        long_message_to_split = false,
      },
    },
  },

  -- Which-key for keybinding hints
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      plugins = {
        marks = true,
        registers = true,
      },
      win = {
        border = "rounded",
      },
    },
  },

  -- Better vim.ui interfaces
  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {
      input = {
        enabled = true,
        default_prompt = "➜ ",
        border = "rounded",
        relative = "cursor",
        prefer_width = 40,
        width = nil,
        max_width = { 140, 0.9 },
        min_width = { 20, 0.2 },
        win_options = {
          winblend = 0,
        },
      },
      select = {
        enabled = true,
        backend = { "fzf_lua", "builtin" },
        trim_prompt = true,
        fzf_lua = {
          winopts = {
            height = 0.5,
            width = 0.5,
          },
        },
      },
    },
  },

  -- Color preview
  {
    "NvChad/nvim-colorizer.lua",
    event = "BufReadPre",
    opts = {
      filetypes = { "*" },
      user_default_options = {
        RGB = true,
        RRGGBB = true,
        names = true,
        RRGGBBAA = true,
        AARRGGBB = true,
        rgb_fn = true,
        hsl_fn = true,
        css = true,
        css_fn = true,
        mode = "background",
        tailwind = true,
        sass = { enable = true, parsers = { "css" } },
        virtualtext = "■",
        always_update = false,
      },
      buftypes = {},
    },
  },

  -- ============================================
  -- TREESITTER (Modern syntax highlighting)
  -- ============================================
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main", -- Required for Neovim 0.12 compatibility fixes
    build = ":TSUpdate",
    lazy = false,
    priority = 900,
    config = function()
      local ts = require("nvim-treesitter")
      local ensure_installed = {
        "bash",
        "c",
        "css",
        "dockerfile",
        "fish",
        "gitignore",
        "go",
        "graphql",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "regex",
        "ruby",
        "rust",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
      }

      ts.setup({})

      local installed = {}
      for _, lang in ipairs(ts.get_installed() or {}) do
        installed[lang] = true
      end
      local missing = {}
      for _, lang in ipairs(ensure_installed) do
        if not installed[lang] then
          table.insert(missing, lang)
        end
      end

      -- Avoid startup errors when `tree-sitter` CLI is not installed.
      if #missing > 0 and vim.fn.executable("tree-sitter") == 1 then
        ts.install(missing, { summary = true })
      end

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
          if pcall(vim.treesitter.get_parser, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Workaround for Neovim 0.12 conceal_line crash when scrolling folded TS/TSX imports.
      -- Disables TS/JS injection queries only (highlighting stays enabled).
      pcall(vim.treesitter.query.set, "typescript", "injections", "")
      pcall(vim.treesitter.query.set, "tsx", "injections", "")
      pcall(vim.treesitter.query.set, "javascript", "injections", "")
      pcall(vim.treesitter.query.set, "javascriptreact", "injections", "")
    end,
  },

  -- Markdown rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {},
  },

  -- Auto close/rename HTML tags
  {
    "windwp/nvim-ts-autotag",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = "InsertEnter",
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = true,
      },
    },
  },

  -- ============================================
  -- SNACKS PICKER (Fast fuzzy finding)
  -- ============================================
  -- fzf-lua config backed up to ~/.config/nvim/backup/init.lua.pre-snacks

  -- ============================================
  -- LSP (Language Server Protocol)
  -- ============================================
  {
    "williamboman/mason.nvim",
    opts = {
      ui = {
        border = "rounded",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "lua_ls",
        "ts_ls",
        "pyright",
        "ruby_lsp",
        "gopls",
        "rust_analyzer",
        "jsonls",
        "yamlls",
        "html",
        "cssls",
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      -- Get cmp capabilities if available
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
      if ok then
        capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
      end

      -- LSP keymaps on attach
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", {}),
        callback = function(ev)
          local opts = { buffer = ev.buf, noremap = true, silent = true }
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
          vim.keymap.set("n", "gtd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
          vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        end,
      })

      -- Configure servers using vim.lsp.config (Neovim 0.11+)
      local servers = {
        ts_ls = {},
        pyright = {},
        ruby_lsp = {
          cmd = {
            "env",
            "BUNDLE_GEMFILE=" .. vim.fn.expand("~/.local/share/nvim/mason/packages/ruby-lsp/Gemfile"),
            "BUNDLE_PATH=" .. vim.fn.expand("~/.local/share/nvim/mason/packages/ruby-lsp"),
            vim.fn.expand("~/.local/share/nvim/mason/bin/ruby-lsp"),
          },
        },
        gopls = {},
        rust_analyzer = {},
        jsonls = {},
        yamlls = {},
        html = {},
        cssls = {},
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = {
                globals = { "vim" },
              },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
              },
              telemetry = {
                enable = false,
              },
            },
          },
        },
      }

      for server, config in pairs(servers) do
        config.capabilities = capabilities
        vim.lsp.config(server, config)
        vim.lsp.enable(server)
      end

      -- Diagnostic config
      vim.diagnostic.config({
        virtual_text = {
          prefix = "●",
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.HINT] = "󰌵 ",
            [vim.diagnostic.severity.INFO] = " ",
          },
        },
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = "rounded",
          source = true,
        },
      })
    end,
  },

  -- LSP progress notifications
  {
    "j-hui/fidget.nvim",
    lazy = false,
    opts = {
      progress = {
        display = {
          done_icon = "✓",
          progress_icon = { pattern = "dots", period = 1 },
        },
      },
      notification = {
        window = {
          winblend = 0,
          relative = "editor",
        },
      },
    },
  },

  -- Highlight word under cursor
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    config = function()
      require("illuminate").configure({
        providers = {
          "lsp",
          "treesitter",
          "regex",
        },
        delay = 100,
        filetypes_denylist = {
          "NvimTree",
          "alpha",
          "toggleterm",
          "TelescopePrompt",
        },
        under_cursor = true,
        min_count_to_highlight = 2,
      })
      vim.api.nvim_set_hl(0, "IlluminatedWordText", { bg = "#2a2a3a" })
      vim.api.nvim_set_hl(0, "IlluminatedWordRead", { bg = "#2a2a3a" })
      vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { bg = "#2a2a3a" })
    end,
  },



  -- ============================================
  -- AI COMPLETION (GitHub Copilot)
  -- ============================================
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        copilot_node_command = "/opt/homebrew/bin/node",
        suggestion = {
          enabled = true,
          auto_trigger = true,  -- Show suggestions automatically
          keymap = {
            accept = "<Tab>",   -- Accept suggestion with Tab
            accept_word = "<C-Right>",  -- Accept word
            accept_line = "<C-Down>",   -- Accept line
            prev = "<M-p>",     -- Previous suggestion (changed from M-[)
            dismiss = "<C-]>",  -- Dismiss suggestion
          },
        },
        panel = { enabled = false },
        filetypes = {
          yaml = true,
          markdown = true,
          gitcommit = true,
          ["*"] = true,
        },
      })
    end,
  },

  -- ============================================
  -- AUTOCOMPLETION
  -- ============================================
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
      {
        "zbirenbaum/copilot-cmp",
        dependencies = "zbirenbaum/copilot.lua",
        config = function()
          require("copilot_cmp").setup()
        end,
      },
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-k>"] = cmp.mapping.select_prev_item(),
          ["<C-j>"] = cmp.mapping.select_next_item(),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            local copilot = require("copilot.suggestion")
            if copilot.is_visible() then
              copilot.accept()
            elseif cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "copilot", group_index = 2 },
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
        formatting = {
          format = function(entry, vim_item)
            local icons = {
              Text = "󰉿",
              Method = "󰆧",
              Function = "󰊕",
              Constructor = "",
              Field = "󰜢",
              Variable = "󰀫",
              Class = "󰠱",
              Interface = "",
              Module = "",
              Property = "󰜢",
              Unit = "󰑭",
              Value = "󰎠",
              Enum = "",
              Keyword = "󰌋",
              Snippet = "",
              Color = "󰏘",
              File = "󰈙",
              Reference = "󰈇",
              Folder = "󰉋",
              EnumMember = "",
              Constant = "󰏿",
              Struct = "󰙅",
              Event = "",
              Operator = "󰆕",
              TypeParameter = "",
              Copilot = "",
            }
            vim_item.kind = string.format("%s %s", icons[vim_item.kind] or "", vim_item.kind)
            vim_item.menu = ({
              copilot = "[AI]",
              nvim_lsp = "[LSP]",
              luasnip = "[Snip]",
              buffer = "[Buf]",
              path = "[Path]",
            })[entry.source.name]
            return vim_item
          end,
        },
      })

      -- Cmdline completion
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" },
        },
      })

      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" },
        }, {
          { name = "cmdline" },
        }),
      })
    end,
  },

  -- ============================================
  -- EDITING ENHANCEMENTS
  -- ============================================

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      local autopairs = require("nvim-autopairs")
      autopairs.setup({
        check_ts = true,
      })

      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },



  -- mini.nvim - Collection of minimal, fast plugins
  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      -- Comment toggling (replaces Comment.nvim)
      require("mini.comment").setup({
        options = {
          ignore_blank_line = true,
        },
        mappings = {
          comment = "gc",
          comment_line = "gcc",
          comment_visual = "gc",
          textobject = "gc",
        },
      })

      -- Surround (replaces nvim-surround, configured with ys/ds/cs keybindings)
      require("mini.surround").setup({
        mappings = {
          add = "ys",            -- Add surrounding (ys{motion}{char})
          delete = "ds",         -- Delete surrounding
          find = "",             -- Disabled (not commonly used)
          find_left = "",        -- Disabled
          highlight = "",        -- Disabled
          replace = "cs",        -- Change surrounding
          update_n_lines = "",   -- Disabled
          suffix_last = "",      -- Disabled
          suffix_next = "",      -- Disabled
        },
      })

      -- Text objects (NEW - game changer!)
      -- Usage: via (inner argument), vaa (outer argument), vif (inner function), etc.
      require("mini.ai").setup({
        n_lines = 500,  -- Search up to 500 lines
        custom_textobjects = {
          -- Custom text objects
          o = require("mini.ai").gen_spec.treesitter({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }, {}),
          f = require("mini.ai").gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
          c = require("mini.ai").gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }, {}),
        },
      })

      require("mini.move").setup({
        mappings = {
          left = "",
          right = "",
          down = "",
          up = "",
          line_left = "",
          line_right = "",
          line_down = "",
          line_up = "",
        },
      })

      -- Better buffer deletion (NEW - preserves window layout)
      require("mini.bufremove").setup()
      vim.keymap.set("n", "<leader>bd", function()
        require("mini.bufremove").delete(0, false)
      end, { desc = "Delete buffer" })
      vim.keymap.set("n", "<leader>bD", function()
        require("mini.bufremove").delete(0, true)
      end, { desc = "Delete buffer (force)" })
    end,
  },

  -- Git signs
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      local gitsigns = require("gitsigns")

      -- Show inline diff with contextual r/s keymaps
      _G.gitsigns_show_inline_diff = function()
        local gs = package.loaded.gitsigns
        local bufnr = vim.api.nvim_get_current_buf()

        local function clear_inline_preview()
          -- Close any gitsigns float windows
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            local config = vim.api.nvim_win_get_config(win)
            if config.relative ~= "" then  -- It's a float
              pcall(vim.api.nvim_win_close, win, true)
            end
          end
          -- Clear extmarks
          local ns = vim.api.nvim_create_namespace("gitsigns_preview_inline")
          vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
          -- Trigger CursorMoved to let gitsigns clean up too
          vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })
        end

        local function cleanup()
          pcall(vim.keymap.del, "n", "r", { buffer = bufnr })
          pcall(vim.keymap.del, "n", "<CR>", { buffer = bufnr })
          pcall(vim.keymap.del, "n", "s", { buffer = bufnr })
          pcall(vim.keymap.del, "n", "q", { buffer = bufnr })
          pcall(vim.keymap.del, "n", "<Esc>", { buffer = bufnr })
          pcall(vim.api.nvim_del_autocmd, vim.b[bufnr]._gitsigns_inline_autocmd)
          vim.b[bufnr]._gitsigns_inline_autocmd = nil
          clear_inline_preview()
        end

        -- Clean up any existing keymaps/preview first
        cleanup()

        gs.preview_hunk_inline()

        vim.keymap.set("n", "r", function()
          cleanup()
          gs.reset_hunk()
          vim.defer_fn(clear_inline_preview, 10)
        end, { buffer = bufnr, nowait = true })

        vim.keymap.set("n", "<CR>", function()
          cleanup()
          gs.reset_hunk()
          vim.defer_fn(clear_inline_preview, 10)
        end, { buffer = bufnr, nowait = true })

        vim.keymap.set("n", "s", function()
          cleanup()
          gs.stage_hunk()
          vim.defer_fn(clear_inline_preview, 10)
        end, { buffer = bufnr, nowait = true })

        vim.keymap.set("n", "<Esc>", function()
          clear_inline_preview()
          cleanup()
        end, { buffer = bufnr, nowait = true })

        vim.keymap.set("n", "q", function()
          clear_inline_preview()
          cleanup()
        end, { buffer = bufnr, nowait = true })

        -- Auto cleanup when cursor moves
        vim.b[bufnr]._gitsigns_inline_autocmd = vim.api.nvim_create_autocmd("CursorMoved", {
          buffer = bufnr,
          once = true,
          callback = cleanup,
        })
      end

      -- Single click on gutter shows inline diff
      vim.keymap.set("n", "<LeftMouse>", function()
        local mouse = vim.fn.getmousepos()
        vim.g._gitsigns_mouse = { screencol = mouse.screencol, line = mouse.line, winid = mouse.winid }
        return "<LeftMouse>"
      end, { expr = true })

      vim.keymap.set("n", "<LeftRelease>", function()
        local mouse = vim.g._gitsigns_mouse
        if mouse and mouse.screencol <= 4 and mouse.winid ~= 0 then
          local bufnr = vim.api.nvim_win_get_buf(mouse.winid)
          local signs = vim.fn.sign_getplaced(bufnr, { group = "*", lnum = mouse.line })
          local has_gitsign = false
          if signs and signs[1] and signs[1].signs then
            for _, sign in ipairs(signs[1].signs) do
              if sign.group and sign.group:match("gitsigns") then
                has_gitsign = true
                break
              end
            end
          end
          if has_gitsign then
            _G.gitsigns_show_inline_diff()
          end
        end
        vim.g._gitsigns_mouse = nil
      end)

      gitsigns.setup({
        signs = {
          add = { text = " │" },
          change = { text = " │" },
          delete = { text = " ▶" },
          topdelete = { text = " ▶" },
          changedelete = { text = " │" },
          untracked = { text = " │" },
        },
        signs_staged = {
          add = { text = " ┃" },
          change = { text = " ┃" },
          delete = { text = " ▶" },
          topdelete = { text = " ▶" },
          changedelete = { text = " ┃" },
        },
        signs_staged_enable = true,
        current_line_blame = true,
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = "eol",
          delay = 300,
        },
        current_line_blame_formatter = "   <author>, <author_time:%R> • <summary>",
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local opts = { buffer = bufnr }

          vim.keymap.set("n", "]c", function()
            if vim.wo.diff then return "]c" end
            vim.schedule(function() gs.next_hunk() end)
            return "<Ignore>"
          end, { expr = true, buffer = bufnr })

          vim.keymap.set("n", "[c", function()
            if vim.wo.diff then return "[c" end
            vim.schedule(function() gs.prev_hunk() end)
            return "<Ignore>"
          end, { expr = true, buffer = bufnr })

          vim.keymap.set("n", "<leader>hs", gs.stage_hunk, opts)
          vim.keymap.set("n", "<leader>hr", gs.reset_hunk, opts)
          vim.keymap.set("n", "<leader>hp", _G.gitsigns_show_inline_diff, opts)
          vim.keymap.set("n", "<leader>hb", function() gs.blame_line({ full = true }) end, opts)
          vim.keymap.set("n", "gd", _G.gitsigns_show_inline_diff, opts)
        end,
      })
    end,
  },

  -- Git diff viewer
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewFileHistory",
    },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open diff view" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
      { "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "Close diff view" },
    },
    opts = {
      enhanced_diff_hl = true,
      use_icons = true,
      view = {
        default = {
          layout = "diff2_horizontal",
        },
        merge_tool = {
          layout = "diff3_horizontal",
        },
      },
    },
  },


  -- Local file replace - lightweight popup like / but for substitution
  {
    "chrisgrieser/nvim-rip-substitute",
    keys = {
      { "<leader>r", function() require("rip-substitute").sub() end, mode = { "n", "x" }, desc = "Replace in file" },
      { "<D-r>", function() require("rip-substitute").sub() end, mode = { "n", "x" }, desc = "Replace in file" },
    },
    opts = {
      popupWin = {
        border = "rounded",
        title = " Replace ",
      },
      prefill = {
        normal = "cursorWord",
        visual = "selectionFirstLine",
      },
    },
  },

  -- Global project-wide replace
  {
    "MagicDuck/grug-far.nvim",
    keys = {
      {
        "<leader>R",
        function() require("grug-far").open() end,
        mode = "n",
        desc = "Replace in project",
      },
      {
        "<D-R>",
        function() require("grug-far").open() end,
        mode = "n",
        desc = "Replace in project",
      },
      {
        "<leader>R",
        function()
          require("grug-far").open({ visualSelectionUsage = "prefill-search" })
        end,
        mode = "v",
        desc = "Replace selection in project",
      },
      {
        "<D-R>",
        function()
          require("grug-far").open({ visualSelectionUsage = "prefill-search" })
        end,
        mode = "v",
        desc = "Replace selection in project",
      },
    },
    opts = {
      startInInsertMode = true,
      transient = true,
      keymaps = {
        close = { n = "<Esc>" },
      },
      engines = {
        ripgrep = {
          extraArgs = "--smart-case --hidden --glob=!*.rbi --glob=!*.snap --glob=!*.tsbuildinfo --glob=!**/node_modules/** --glob=!**/dist/** --glob=!**/build/** --glob=!**/coverage/** --glob=!**/tmp/** --glob=!**/artifacts/** --glob=!**/test-results/** --glob=!**/playwright-report/** --glob=!**/blob-report/** --glob=!**/.dev/** --glob=!**/.nx/** --glob=!**/.vite/** --glob=!**/translations/** --glob=!**/generated/**",
        },
      },
    },
    config = function(_, opts)
      local grug_far = require("grug-far")
      grug_far.setup(opts)

      grug_far._createWindow = function(context)
        context.prevWin = vim.api.nvim_get_current_win()
        local prevBuf = vim.api.nvim_win_get_buf(context.prevWin)
        context.prevBufName = vim.api.nvim_buf_get_name(prevBuf)
        context.prevBufFiletype = vim.bo[prevBuf].filetype

        local width = math.min(120, math.floor(vim.o.columns * 0.8))
        local height = math.min(35, math.floor(vim.o.lines * 0.7))
        local win = vim.api.nvim_open_win(0, true, {
          relative = "editor",
          width = width,
          height = height,
          col = math.floor((vim.o.columns - width) / 2),
          row = math.floor((vim.o.lines - height) / 2),
          style = "minimal",
          border = "rounded",
          title = " Search & Replace (Project) ",
          title_pos = "center",
        })
        context.initialWin = win
        return win
      end
    end,
  },

  -- Better escape
  {
    "max397574/better-escape.nvim",
    config = function()
      require("better_escape").setup({
        timeout = 200,
        default_mappings = false,
        mappings = {
          i = {
            j = {
              j = "<Esc>",
            },
          },
        },
      })
    end,
  },

-- ============================================
  -- QUALITY OF LIFE
  -- ============================================



-- Dashboard
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        [[                                                    ]],
        [[  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗]],
        [[  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║]],
        [[  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║]],
        [[  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║]],
        [[  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║]],
        [[  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
        [[                                                    ]],
      }

      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file", ":lua _G.files_by_length()<CR>"),
        dashboard.button("r", "  Recent files", ":lua _G.find_oldfiles()<CR>"),
        dashboard.button("d", "  Git diff files", ":lua _G.git_changed_files()<CR>"),
        dashboard.button("g", "  Find text", ":lua _G.project_grep()<CR>"),
        dashboard.button("c", "  Config", ":e ~/.config/nvim/init.lua<CR>"),
        dashboard.button("l", "󰒲  Lazy", ":Lazy<CR>"),
        dashboard.button("q", "  Quit", ":qa<CR>"),
      }

      vim.api.nvim_set_hl(0, "AlphaHeader", { fg = "#E0E0E0", italic = false })
      vim.api.nvim_set_hl(0, "AlphaButtons", { fg = "#D8D8D8", italic = false })
      vim.api.nvim_set_hl(0, "AlphaFooter", { fg = "#A0A0A0", italic = false })

      dashboard.section.header.opts.hl = "AlphaHeader"
      dashboard.section.buttons.opts.hl = "AlphaButtons"
      dashboard.section.footer.opts.hl = "AlphaFooter"

      alpha.setup(dashboard.opts)
    end,
  },



  -- Trouble - Better diagnostics and quickfix list
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Trouble",
    keys = {
      { "xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
      { "xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
      { "xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols (Trouble)" },
      { "xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP Definitions / references / ... (Trouble)" },
      { "xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix List (Trouble)" },
    },
    opts = {},
  },

  -- Flash - Fast cursor movement
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      labels = "asdfghjklqwertyuiopzxcvbnm",
      search = {
        multi_window = true,
        forward = true,
        wrap = true,
      },
      jump = {
        autojump = false,
      },
      label = {
        uppercase = false,
        rainbow = {
          enabled = true,
        },
      },
      modes = {
        char = {
          enabled = false,  -- Disable flash on f/F/t/T (keep default behavior)
        },
      },
    },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },

  -- Treesitter Context - Sticky function/class header
  {
    "nvim-treesitter/nvim-treesitter-context",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = "BufReadPost",
    opts = {
      enable = false,
      max_lines = 3,  -- Maximum number of context lines
      min_window_height = 20,  -- Minimum window height
      line_numbers = true,
      multiline_threshold = 1,
      trim_scope = "outer",  -- Remove outer whitespace
      mode = "cursor",  -- Show context based on cursor position
      separator = "─",
    },
    keys = {
      { "<leader>tc", "<cmd>TSContext toggle<cr>", desc = "Toggle Treesitter Context" },
    },
  },

  -- Todo comments
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },

  -- Lazygit integration
  {
    "kdheepak/lazygit.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
      { "<leader>lf", "<cmd>LazyGitFilterCurrentFile<cr>", desc = "LazyGit file history" },
    },
    config = function()
      vim.g.lazygit_floating_window_scaling_factor = 0.9
      vim.g.lazygit_floating_window_border_chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
    end,
  },

  -- Smooth cursor trail
  {
    "gen740/SmoothCursor.nvim",
    config = function()
      require("smoothcursor").setup({
        type = "default",
        cursor = "",
        fancy = {
          enable = true,
          head = { cursor = "▷", texthl = "SmoothCursor" },
          body = {
            { cursor = "●", texthl = "SmoothCursorBody" },
            { cursor = "•", texthl = "SmoothCursorBody" },
            { cursor = "·", texthl = "SmoothCursorBody" },
          },
        },
        speed = 25,
        intervals = 35,
        priority = 10,
        timeout = 3000,
        threshold = 1,
        disable_float_win = true,
        disabled_filetypes = { "NvimTree", "alpha" },
      })
      vim.api.nvim_set_hl(0, "SmoothCursor", { fg = "#c4a7e7" })  -- Rose Pine iris
      vim.api.nvim_set_hl(0, "SmoothCursorBody", { fg = "#9ccfd8" })  -- Rose Pine foam
    end,
  },

  -- Claude Code integration
  {
    "folke/snacks.nvim",
    lazy = false,
    config = function()
      require("snacks").setup({
        picker = {
          enabled = true,
          layout = {
            preset = "default",
            layout = {
              width = 0.95,
              height = 0.85,
              border = "rounded",
            },
          },
          formatters = {
            file = {
              filename_first = true,
              icon_width = 3,
            },
          },
          exclude = {
            "*.rbi",
            "*.snap",
            "*.tsbuildinfo",
            "**/node_modules/**",
            "**/dist/**",
            "**/build/**",
            "**/coverage/**",
            "**/tmp/**",
            "**/artifacts/**",
            "**/test-results/**",
            "**/playwright-report/**",
            "**/blob-report/**",
            "**/.dev/**",
            "**/.nx/**",
            "**/.vite/**",
            "**/translations/**",
            "**/generated/**",
          },
          sources = {
            files = {
              hidden = true,
              ignored = false,
            },
            grep = {
              hidden = true,
              ignored = false,
            },
          },
          win = {
            input = {
              keys = {
                ["<Esc>"] = { "close", mode = { "n", "i" } },
                ["<C-q>"] = { "close", mode = { "n", "i" } },
                ["<C-u>"] = { function(picker) picker.input:set("") end, mode = { "n", "i" }, desc = "Clear input" },
                ["<C-d>"] = { "preview_scroll_down", mode = { "n", "i" } },

              },
            },
          },
        },
        styles = {
          terminal = {
            border = "rounded",
            width = 0.35,
            wo = {
              winbar = "",
              cursorline = false,
              cursorcolumn = false,
              scrolloff = 0,
              signcolumn = "no",
              foldcolumn = "0",
              winhighlight = "TermCursor:TermCursorHidden,TermCursorNC:TermCursorHidden",
            },
            bo = {
              scrollback = 10000,
            },
          },
        },
      })
      vim.api.nvim_set_hl(0, "TermCursorHidden", { blend = 100, nocombine = true })
      vim.api.nvim_set_hl(0, "lualine_c_filePath", { fg = "#5c5c7a", bg = "#0A0D16" })

      -- Intercept paste in picker: strip long paths to just the filename
      local original_paste = vim.paste
      vim.paste = function(lines, phase)
        -- Check if a snacks picker input is focused
        local buf = vim.api.nvim_get_current_buf()
        local bt = vim.bo[buf].filetype
        if bt == "snacks_picker_input" or bt == "snacks_input" then
          for i, line in ipairs(lines) do
            if line:find("/") then
              lines[i] = line:match("([^/]+)$") or line
            end
            lines[i] = vim.trim(lines[i])
          end
        end
        return original_paste(lines, phase)
      end

      -- Snacks picker keymaps
      local pick = require("snacks").picker
      local nw = { noremap = true, silent = true, nowait = true }

      _G.project_grep = function()
        return pick.grep()
      end

      -- Disable built-in f (find char) so f* picker mappings fire instantly
      -- Use Flash.nvim's s for jumping to characters instead
      vim.keymap.set("n", "f", "<Nop>", nw)
      vim.keymap.set("n", "ff", pick.files, vim.tbl_extend("force", nw, { desc = "Find files" }))
      vim.keymap.set("n", "<C-p>", pick.files, { desc = "Find files" })
      vim.keymap.set("n", "fg", _G.project_grep, vim.tbl_extend("force", nw, { desc = "Search in project" }))
      vim.keymap.set("n", "<leader>F", _G.project_grep, { desc = "Search in project" })
      vim.keymap.set("n", "<D-f>", pick.lines, { desc = "Search in file" })
      vim.keymap.set("n", "<D-F>", _G.project_grep, { desc = "Search in project" })
      vim.keymap.set("n", "fb", pick.buffers, vim.tbl_extend("force", nw, { desc = "Buffers" }))
      vim.keymap.set("n", "fr", function() pick.recent({ filter = { cwd = true } }) end, vim.tbl_extend("force", nw, { desc = "Recent files" }))
      -- Cache for git changed files (pre-warmed on startup so fc is always instant)
      local git_changed_cache = { files = nil, cwd = nil, time = 0 }
      local active_changed_picker = nil
      local prewarm_scheduled = false

      local function format_age(seconds)
        if seconds < 60 then return math.floor(seconds) .. "s ago" end
        if seconds < 3600 then return math.floor(seconds / 60) .. "m ago" end
        return math.floor(seconds / 3600) .. "h ago"
      end

      local git_root_cache = nil
      local function get_git_root()
        if git_root_cache then return git_root_cache end
        local result = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
        git_root_cache = result and result ~= "" and result or vim.fn.getcwd()
        return git_root_cache
      end

      local function get_modified_buffers(git_root)
        local modified = {}
        local seen = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= "" and name:find(git_root, 1, true) == 1 then
              local rel = name:sub(#git_root + 2)
              if not seen[rel] then
                table.insert(modified, rel)
                seen[rel] = true
              end
            end
          end
        end
        return modified, seen
      end

      local function sort_by_mtime(files, git_root)
        local mtimes = {}
        for _, f in ipairs(files) do
          local stat = vim.uv.fs_stat(git_root .. "/" .. f)
          mtimes[f] = stat and stat.mtime.sec or 0
        end
        table.sort(files, function(a, b) return mtimes[a] > mtimes[b] end)
      end

      -- Resolve the branch's fork point from the main line, for showing
      -- committed (on-branch) changes in addition to uncommitted ones.
      local git_base_cmd =
        "git merge-base HEAD origin/main 2>/dev/null"
        .. " || git merge-base HEAD origin/master 2>/dev/null"
        .. " || git merge-base HEAD main 2>/dev/null"
        .. " || git merge-base HEAD master 2>/dev/null || true"

      local function refresh_git_cache(git_root, on_done)
        -- Union of: committed-on-branch (base..HEAD), uncommitted (vs HEAD),
        -- and untracked files. Deduped below by the `seen` set.
        local list_script =
          "base=$(" .. git_base_cmd .. "); "
          .. '[ -n "$base" ] && git diff --name-only "$base" HEAD; '
          .. "git diff --name-only HEAD; "
          .. "git ls-files --others --exclude-standard"
        vim.system(
          { "sh", "-c", list_script },
          { text = true, cwd = git_root },
          vim.schedule_wrap(function(result)
            if result.code ~= 0 then return end
            local files = {}
            local seen = {}
            -- Add modified buffers first (unsaved changes)
            local mod_files, mod_seen = get_modified_buffers(git_root)
            for _, f in ipairs(mod_files) do
              table.insert(files, f)
              seen[f] = true
            end
            -- Add git changes, skipping sparse-checkout ghosts (files not on disk)
            for line in result.stdout:gmatch("[^\n]+") do
              if not seen[line] and vim.uv.fs_stat(git_root .. "/" .. line) then
                table.insert(files, line)
                seen[line] = true
              end
            end
            -- Sort by most recently modified on disk
            sort_by_mtime(files, git_root)
            -- Always update cache (including empty results, so stale files don't linger)
            git_changed_cache = { files = files, cwd = git_root, time = vim.uv.now() / 1000 }
            if on_done then on_done(files) end
          end)
        )
      end

      -- Pre-warm the cache on startup so first fc press is instant
      vim.defer_fn(function()
        local root = get_git_root()
        if root then refresh_git_cache(root, function() end) end
      end, 500)

      local refresh_timer = nil
      local open_changed_picker -- forward declaration

      local function stop_refresh_timer()
        if refresh_timer then
          refresh_timer:stop()
          refresh_timer:close()
          refresh_timer = nil
        end
      end

      local function start_refresh_timer(git_root)
        stop_refresh_timer()
        refresh_timer = vim.uv.new_timer()
        refresh_timer:start(10000, 10000, vim.schedule_wrap(function()
          if not active_changed_picker then
            stop_refresh_timer()
            return
          end
          refresh_git_cache(git_root, function(fresh_files)
            if active_changed_picker then
              local age = (vim.uv.now() / 1000) - git_changed_cache.time
              open_changed_picker(fresh_files, git_root, format_age(age))
            end
          end)
        end))
      end

      local function make_items(files, cwd)
        local items = {}
        for i, f in ipairs(files) do
          items[i] = { text = f, file = f, cwd = cwd, idx = i }
        end
        return items
      end

      open_changed_picker = function(files, cwd, age_str)
        local title = "Changed Files"
        if age_str then title = title .. "  (" .. age_str .. ")" end

        -- If picker is already open, update items in-place only if they changed
        -- Guard: check if the picker window is still actually open
        if active_changed_picker then
          local ok, win_valid = pcall(function()
            return active_changed_picker.input
              and active_changed_picker.input.win
              and active_changed_picker.input.win.win
              and vim.api.nvim_win_is_valid(active_changed_picker.input.win.win)
          end)
          if not ok or not win_valid then
            active_changed_picker = nil
          end
        end
        if active_changed_picker then
          -- Check if files actually changed
          local old_texts = {}
          for _, item in ipairs(active_changed_picker.list.items) do
            old_texts[#old_texts + 1] = item.text
          end
          local changed = #old_texts ~= #files
          if not changed then
            for i, f in ipairs(files) do
              if old_texts[i] ~= f then
                changed = true
                break
              end
            end
          end
          -- Update the picker title (e.g. loading… → just now)
          pcall(function()
            active_changed_picker.layout.root:set_title(" " .. title .. " ")
          end)
          if not changed then return end
          -- Remember which file was selected by name
          local cur = active_changed_picker.list.cursor
          local selected_file = nil
          if cur >= 1 and cur <= #active_changed_picker.list.items then
            selected_file = active_changed_picker.list.items[cur].text
          end
          -- Replace items directly (avoid clear which flashes "no results")
          local items = make_items(files, cwd)
          active_changed_picker.list.items = items
          active_changed_picker.list.dirty = true
          -- Restore cursor to same file, or clamp
          local new_cursor = 1
          if selected_file then
            for i, item in ipairs(items) do
              if item.text == selected_file then
                new_cursor = i
                break
              end
            end
          end
          active_changed_picker.list.cursor = new_cursor
          active_changed_picker.list:update({ force = true })
          return
        end

        active_changed_picker = require("snacks").picker({
          items = make_items(files, cwd),
          show_empty = true,
          format = "file",
          preview = function(ctx)
            -- Diff against the branch base so committed-on-branch changes
            -- show content too (base..worktree = committed + uncommitted).
            local script = "base=$(" .. git_base_cmd
              .. '); git --no-pager diff --color=never ${base:+"$base"} -- "$1"'
            local cmd = { "sh", "-c", script, "sh", ctx.item.file }
            require("snacks.picker.preview").cmd(cmd, ctx, { ft = "diff", term = false })
          end,
          previewers = { diff = { style = "plain" } },
          confirm = function(picker, item)
            picker:close()
            if not item then return end
            local path = item.file
            if item.cwd and not path:match("^/") then
              path = item.cwd .. "/" .. path
            end
            vim.schedule(function()
              vim.cmd("edit " .. vim.fn.fnameescape(path))
            end)
          end,
          on_close = function()
            active_changed_picker = nil
            stop_refresh_timer()
          end,
        })
        -- Set title on the outer layout root (the only border that shows a title)
        pcall(function()
          active_changed_picker.layout.root:set_title(" " .. title .. " ")
        end)
      end

      _G.git_changed_files = function()
        local git_root = get_git_root()
        local cache = git_changed_cache

        -- Show cached results immediately if available, otherwise show loading notice
        local has_cache = cache.files and cache.cwd == git_root
        if has_cache then
          local files = vim.deepcopy(cache.files)
          local seen = {}
          for _, f in ipairs(files) do seen[f] = true end
          local mod_files = get_modified_buffers(git_root)
          for _, f in ipairs(mod_files) do
            if not seen[f] then
              table.insert(files, 1, f)
            end
          end
          local age = (vim.uv.now() / 1000) - cache.time
          open_changed_picker(files, git_root, format_age(age))
        else
          open_changed_picker({}, git_root, "loading…")
        end
        -- Refresh in background only if cache is stale (>5s old)
        local cache_age = has_cache and ((vim.uv.now() / 1000) - cache.time) or math.huge
        if cache_age > 5 then
          refresh_git_cache(git_root, function(fresh_files)
            if active_changed_picker then
              local age = (vim.uv.now() / 1000) - git_changed_cache.time
              open_changed_picker(fresh_files, git_root, format_age(age))
            end
          end)
        end
        start_refresh_timer(git_root)
      end
      vim.keymap.set("n", "fc", _G.git_changed_files, vim.tbl_extend("force", nw, { desc = "Changed files (git)" }))
      vim.keymap.set("n", "fh", pick.help, vim.tbl_extend("force", nw, { desc = "Help tags" }))
      vim.keymap.set("n", "f:", pick.commands, vim.tbl_extend("force", nw, { desc = "Commands" }))
      vim.keymap.set("n", "fs", pick.lsp_symbols, vim.tbl_extend("force", nw, { desc = "Document symbols" }))

      -- Global functions for dashboard
      _G.files_by_length = function() pick.files() end
      _G.find_oldfiles = function() pick.recent({ filter = { cwd = true } }) end

      -- Seamless scrolling in all terminals including Claude
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function()
          vim.defer_fn(function()
            local opts = { buffer = 0, silent = true, nowait = true }

            -- Scroll keybindings - exit terminal mode and stay in normal mode with boundary checks
            vim.keymap.set("t", "<C-u>", function()
              vim.cmd("stopinsert")
              vim.cmd("normal! \022u")
            end, opts)

            vim.keymap.set("t", "<C-d>", function()
              vim.cmd("stopinsert")
              local win = vim.api.nvim_get_current_win()
              local buf = vim.api.nvim_get_current_buf()
              local buf_lines = vim.api.nvim_buf_line_count(buf)
              local win_height = vim.api.nvim_win_get_height(win)
              local top_line = vim.fn.line("w0")

              if top_line + win_height - 1 < buf_lines then
                vim.cmd("normal! \022d")
              end
            end, opts)

            vim.keymap.set("t", "<C-b>", function()
              vim.cmd("stopinsert")
              vim.cmd("normal! \022b")
            end, opts)

            vim.keymap.set("t", "<C-f>", function()
              vim.cmd("stopinsert")
              local win = vim.api.nvim_get_current_win()
              local buf = vim.api.nvim_get_current_buf()
              local buf_lines = vim.api.nvim_buf_line_count(buf)
              local win_height = vim.api.nvim_win_get_height(win)
              local top_line = vim.fn.line("w0")

              if top_line + win_height - 1 < buf_lines then
                vim.cmd("normal! \022f")
              end
            end, opts)

            -- Cmd+Up/Down for Mac-style scrolling (half page)
            vim.keymap.set("t", "<D-Up>", function()
              vim.cmd("stopinsert")
              vim.cmd("normal! \022u")
            end, opts)

            vim.keymap.set("t", "<D-Down>", function()
              vim.cmd("stopinsert")
              local win = vim.api.nvim_get_current_win()
              local buf = vim.api.nvim_get_current_buf()
              local buf_lines = vim.api.nvim_buf_line_count(buf)
              local win_height = vim.api.nvim_win_get_height(win)
              local top_line = vim.fn.line("w0")

              if top_line + win_height - 1 < buf_lines then
                vim.cmd("normal! \022d")
              end
            end, opts)

            -- ESC in terminal mode: close floating terminals, normal mode for splits
            vim.keymap.set("t", "<Esc>", function()
              local win_config = vim.api.nvim_win_get_config(0)

              -- If it's a floating window (like fzf-lua), close it immediately
              if win_config.relative ~= "" then
                vim.cmd("close")
              else
                -- Regular split terminal: switch to normal mode
                vim.cmd("stopinsert")
              end
            end, opts)

            -- ESC in normal mode: close popup terminals, send ESC to split terminals
            vim.keymap.set("n", "<Esc>", function()
              if vim.bo.buftype == "terminal" then
                local win_config = vim.api.nvim_win_get_config(0)
                if win_config.relative ~= "" then
                  -- It's a floating/popup window, close it
                  vim.cmd("close")
                else
                  -- Split terminal: send ESC to terminal without entering insert mode
                  local chan = vim.bo.channel
                  if chan then
                    vim.api.nvim_chan_send(chan, vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
                  end
                end
              end
            end, opts)

            -- Mouse wheel scrolling in normal mode with boundary checks
            vim.keymap.set("n", "<ScrollWheelDown>", function()
              local win = vim.api.nvim_get_current_win()
              local buf = vim.api.nvim_get_current_buf()
              local buf_lines = vim.api.nvim_buf_line_count(buf)
              local win_height = vim.api.nvim_win_get_height(win)
              local top_line = vim.fn.line("w0")

              if top_line + win_height - 1 < buf_lines then
                local key = vim.api.nvim_replace_termcodes("<C-e><C-e><C-e>", true, false, true)
                vim.api.nvim_feedkeys(key, "n", false)
              end
            end, opts)

            vim.keymap.set("n", "<ScrollWheelUp>", function()
              local view = vim.fn.winsaveview()
              if view.topline > 1 then
                local key = vim.api.nvim_replace_termcodes("<C-y><C-y><C-y>", true, false, true)
                vim.api.nvim_feedkeys(key, "n", false)
              end
            end, opts)
          end, 100)
        end,
      })
    end,
  },


  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
      hide_numbers = true,
      shade_terminals = false,
      start_in_insert = true,
      persist_size = true,
      direction = "float",
      close_on_exit = true,
      shell = vim.o.shell,
      float_opts = {
        border = "rounded",
        width = function()
          return math.floor(vim.o.columns * 0.8)
        end,
        height = function()
          return math.floor(vim.o.lines * 0.8)
        end,
      },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*toggleterm#*",
        callback = function()
          local opts = { buffer = 0 }
          vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
          vim.keymap.set("n", "<esc>", "<cmd>close<CR>", opts)
        end,
      })

      vim.keymap.set("n", "<leader>tt", "<cmd>ToggleTerm direction=float<cr>", { desc = "Toggle floating terminal" })
    end,
  },

  -- ============================================
  -- PI IDE CONTEXT (writes editor state for Pi)
  -- ============================================
  {
    dir = vim.fn.expand("~/.local/share/nvim/site/pack/pi/start/ide-context.nvim"),
    name = "ide-context.nvim",
    lazy = false,
  },
}
