-- Synthwave colorscheme matching fish prompt colors
local M = {}

-- Color palette from fish prompt
local colors = {
  bg = "#0a0c14",
  bg_dark = "#070810",
  bg_light = "#12121a",
  bg_cursorline = "#111520",
  bg_highlight = "#252538",
  fg = "#bfb4e3",
  fg_dark = "#a89dd4",
  fg_dim = "#5c5c7a",

  -- Primary colors (purple is main, no green)
  purple = "#ff7edb",    -- Main accent - keywords, functions
  yellow = "#ffcc66",    -- Constants, types, warnings
  red = "#ff5c8d",       -- Errors
  orange = "#ffcc66",    -- Secondary accent
  violet = "#c691e8",    -- Properties, fields

  -- Secondary
  lavender = "#bfb4e3",  -- Same as fg
  gray = "#3d3d5c",
  white = "#e4d8ff",

  none = "NONE",
}

-- Aliases for semantic use
colors.magenta = colors.purple
colors.pink = colors.purple
colors.blue = colors.violet
colors.error = colors.red
colors.warning = colors.yellow
colors.info = colors.violet
colors.hint = colors.lavender
colors.git_add = colors.yellow
colors.git_change = colors.yellow
colors.git_delete = colors.red

function M.setup()
  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end
  vim.o.termguicolors = true
  vim.g.colors_name = "synthwave"

  local highlights = {
    -- Editor
    Normal = { fg = colors.fg, bg = colors.bg },
    NormalFloat = { fg = colors.fg, bg = colors.bg_light },
    FloatBorder = { fg = colors.purple, bg = colors.bg_light },
    ColorColumn = { bg = colors.bg_light },
    Cursor = { fg = colors.bg, bg = colors.purple },
    CursorLine = { bg = colors.bg_cursorline },
    CursorLineNr = { fg = colors.purple, bold = true },
    LineNr = { fg = colors.gray },
    SignColumn = { fg = colors.fg, bg = colors.bg },
    VertSplit = { fg = colors.gray },
    WinSeparator = { fg = colors.gray },

    -- Popup menu
    Pmenu = { fg = colors.fg, bg = colors.bg_light },
    PmenuSel = { fg = colors.bg, bg = colors.purple },
    PmenuSbar = { bg = colors.bg_highlight },
    PmenuThumb = { bg = colors.purple },

    -- Search
    Search = { fg = colors.bg, bg = colors.yellow },
    IncSearch = { fg = colors.bg, bg = colors.purple },
    CurSearch = { fg = colors.bg, bg = colors.yellow },

    -- Visual
    Visual = { bg = colors.bg_highlight },
    VisualNOS = { bg = colors.bg_highlight },

    -- Diff
    DiffAdd = { fg = colors.yellow, bg = colors.bg },
    DiffChange = { fg = colors.yellow, bg = colors.bg },
    DiffDelete = { fg = colors.red, bg = colors.bg },
    DiffText = { fg = colors.yellow, bg = colors.bg_highlight },

    -- Folding
    Folded = { fg = colors.fg_dim, bg = colors.bg_light },
    FoldColumn = { fg = colors.gray, bg = colors.bg },

    -- Status line
    StatusLine = { fg = colors.fg, bg = colors.bg_light },
    StatusLineNC = { fg = colors.fg_dim, bg = colors.bg_dark },

    -- Tab line
    TabLine = { fg = colors.fg_dim, bg = colors.bg_dark },
    TabLineSel = { fg = colors.purple, bg = colors.bg, bold = true },
    TabLineFill = { bg = colors.bg_dark },

    -- Messages
    ModeMsg = { fg = colors.fg, bold = true },
    MoreMsg = { fg = colors.purple },
    Question = { fg = colors.purple },
    WarningMsg = { fg = colors.yellow },
    ErrorMsg = { fg = colors.red },

    -- Misc
    NonText = { fg = colors.gray },
    SpecialKey = { fg = colors.gray },
    Directory = { fg = colors.purple },
    Title = { fg = colors.purple, bold = true },
    Conceal = { fg = colors.gray },
    MatchParen = { fg = colors.yellow, bold = true, underline = true },

    -- Syntax
    Comment = { fg = colors.fg_dim, italic = true },
    Constant = { fg = colors.yellow },
    String = { fg = colors.lavender },
    Character = { fg = colors.lavender },
    Number = { fg = colors.yellow },
    Boolean = { fg = colors.purple },
    Float = { fg = colors.yellow },

    Identifier = { fg = colors.fg },
    Function = { fg = colors.purple },

    Statement = { fg = colors.purple },
    Conditional = { fg = colors.purple },
    Repeat = { fg = colors.purple },
    Label = { fg = colors.purple },
    Operator = { fg = colors.fg },
    Keyword = { fg = colors.purple },
    Exception = { fg = colors.red },

    PreProc = { fg = colors.purple },
    Include = { fg = colors.purple },
    Define = { fg = colors.purple },
    Macro = { fg = colors.purple },
    PreCondit = { fg = colors.purple },

    Type = { fg = colors.yellow },
    StorageClass = { fg = colors.purple },
    Structure = { fg = colors.yellow },
    Typedef = { fg = colors.yellow },

    Special = { fg = colors.purple },
    SpecialChar = { fg = colors.purple },
    Tag = { fg = colors.purple },
    Delimiter = { fg = colors.fg },
    SpecialComment = { fg = colors.fg_dim },
    Debug = { fg = colors.red },

    Underlined = { underline = true },
    Ignore = { fg = colors.gray },
    Error = { fg = colors.red },
    Todo = { fg = colors.bg, bg = colors.yellow, bold = true },

    -- Treesitter
    ["@comment"] = { link = "Comment" },
    ["@error"] = { fg = colors.red },
    ["@none"] = { fg = colors.fg },
    ["@preproc"] = { fg = colors.purple },
    ["@define"] = { fg = colors.purple },
    ["@operator"] = { fg = colors.fg },

    ["@punctuation.delimiter"] = { fg = colors.fg },
    ["@punctuation.bracket"] = { fg = colors.fg },
    ["@punctuation.special"] = { fg = colors.purple },

    ["@string"] = { fg = colors.lavender },
    ["@string.regex"] = { fg = colors.yellow },
    ["@string.escape"] = { fg = colors.purple },
    ["@string.special"] = { fg = colors.lavender },

    ["@character"] = { fg = colors.lavender },
    ["@character.special"] = { fg = colors.lavender },

    ["@boolean"] = { fg = colors.purple },
    ["@number"] = { fg = colors.yellow },
    ["@float"] = { fg = colors.yellow },

    ["@function"] = { fg = colors.purple },
    ["@function.builtin"] = { fg = colors.purple },
    ["@function.call"] = { fg = colors.purple },
    ["@function.macro"] = { fg = colors.purple },

    ["@method"] = { fg = colors.purple },
    ["@method.call"] = { fg = colors.purple },

    ["@constructor"] = { fg = colors.yellow },
    ["@parameter"] = { fg = colors.fg, italic = true },

    ["@keyword"] = { fg = colors.purple },
    ["@keyword.function"] = { fg = colors.purple },
    ["@keyword.operator"] = { fg = colors.purple },
    ["@keyword.return"] = { fg = colors.purple },

    ["@conditional"] = { fg = colors.purple },
    ["@repeat"] = { fg = colors.purple },
    ["@label"] = { fg = colors.purple },
    ["@include"] = { fg = colors.purple },
    ["@exception"] = { fg = colors.red },

    ["@type"] = { fg = colors.yellow },
    ["@type.builtin"] = { fg = colors.yellow },
    ["@type.definition"] = { fg = colors.yellow },
    ["@type.qualifier"] = { fg = colors.purple },

    ["@storageclass"] = { fg = colors.purple },
    ["@attribute"] = { fg = colors.purple },
    ["@field"] = { fg = colors.violet },
    ["@property"] = { fg = colors.violet },

    ["@variable"] = { fg = colors.fg },
    ["@variable.builtin"] = { fg = colors.purple },

    ["@constant"] = { fg = colors.yellow },
    ["@constant.builtin"] = { fg = colors.yellow },
    ["@constant.macro"] = { fg = colors.purple },

    ["@namespace"] = { fg = colors.fg },
    ["@symbol"] = { fg = colors.yellow },

    ["@text"] = { fg = colors.fg },
    ["@text.title"] = { fg = colors.purple, bold = true },
    ["@text.literal"] = { fg = colors.lavender },
    ["@text.uri"] = { fg = colors.purple, underline = true },
    ["@text.math"] = { fg = colors.yellow },
    ["@text.environment"] = { fg = colors.purple },
    ["@text.environment.name"] = { fg = colors.yellow },
    ["@text.reference"] = { fg = colors.purple },
    ["@text.todo"] = { link = "Todo" },
    ["@text.note"] = { fg = colors.bg, bg = colors.lavender },
    ["@text.warning"] = { fg = colors.bg, bg = colors.yellow },
    ["@text.danger"] = { fg = colors.bg, bg = colors.red },

    ["@tag"] = { fg = colors.purple },
    ["@tag.attribute"] = { fg = colors.yellow },
    ["@tag.delimiter"] = { fg = colors.fg },

    -- LSP Semantic tokens
    ["@lsp.type.class"] = { fg = colors.yellow },
    ["@lsp.type.decorator"] = { fg = colors.purple },
    ["@lsp.type.enum"] = { fg = colors.yellow },
    ["@lsp.type.enumMember"] = { fg = colors.yellow },
    ["@lsp.type.function"] = { fg = colors.purple },
    ["@lsp.type.interface"] = { fg = colors.yellow },
    ["@lsp.type.macro"] = { fg = colors.purple },
    ["@lsp.type.method"] = { fg = colors.purple },
    ["@lsp.type.namespace"] = { fg = colors.fg },
    ["@lsp.type.parameter"] = { fg = colors.fg, italic = true },
    ["@lsp.type.property"] = { fg = colors.violet },
    ["@lsp.type.struct"] = { fg = colors.yellow },
    ["@lsp.type.type"] = { fg = colors.yellow },
    ["@lsp.type.variable"] = { fg = colors.fg },

    -- Diagnostics
    DiagnosticError = { fg = colors.red },
    DiagnosticWarn = { fg = colors.yellow },
    DiagnosticInfo = { fg = colors.violet },
    DiagnosticHint = { fg = colors.lavender },
    DiagnosticUnderlineError = { undercurl = true, sp = colors.red },
    DiagnosticUnderlineWarn = { undercurl = true, sp = colors.yellow },
    DiagnosticUnderlineInfo = { undercurl = true, sp = colors.lavender },
    DiagnosticUnderlineHint = { undercurl = true, sp = colors.lavender },
    DiagnosticVirtualTextError = { fg = colors.red, bg = colors.bg_light },
    DiagnosticVirtualTextWarn = { fg = colors.yellow, bg = colors.bg_light },
    DiagnosticVirtualTextInfo = { fg = colors.lavender, bg = colors.bg_light },
    DiagnosticVirtualTextHint = { fg = colors.lavender, bg = colors.bg_light },

    -- LSP
    LspReferenceText = { bg = colors.bg_highlight },
    LspReferenceRead = { bg = colors.bg_highlight },
    LspReferenceWrite = { bg = colors.bg_highlight },
    LspSignatureActiveParameter = { fg = colors.yellow, bold = true },

    -- Git Signs
    GitSignsAdd = { fg = colors.yellow },
    GitSignsChange = { fg = colors.yellow },
    GitSignsDelete = { fg = colors.red },

    -- Neo-tree
    NeoTreeNormal = { fg = colors.fg, bg = colors.bg_dark },
    NeoTreeNormalNC = { fg = colors.fg, bg = colors.bg_dark },
    NeoTreeDirectoryName = { fg = colors.violet },
    NeoTreeDirectoryIcon = { fg = colors.violet },
    NeoTreeRootName = { fg = colors.yellow, bold = true },
    NeoTreeFileName = { fg = colors.fg },
    NeoTreeFileIcon = { fg = colors.fg },
    NeoTreeGitAdded = { fg = colors.yellow },
    NeoTreeGitModified = { fg = colors.yellow },
    NeoTreeGitDeleted = { fg = colors.red },
    NeoTreeIndentMarker = { fg = colors.gray },

    -- Telescope
    TelescopeBorder = { fg = colors.purple },
    TelescopePromptBorder = { fg = colors.purple },
    TelescopePromptTitle = { fg = colors.purple },
    TelescopePreviewTitle = { fg = colors.yellow },
    TelescopeResultsTitle = { fg = colors.yellow },
    TelescopeSelection = { bg = colors.bg_highlight },
    TelescopeMatching = { fg = colors.yellow, bold = true },

    -- Indent Blankline
    IblIndent = { fg = "#101018" },
    IblScope = { fg = "#181822" },

    -- Which Key
    WhichKey = { fg = colors.purple },
    WhichKeyGroup = { fg = colors.yellow },
    WhichKeyDesc = { fg = colors.fg },
    WhichKeySeperator = { fg = colors.gray },
    WhichKeyFloat = { bg = colors.bg_light },

    -- Notify
    NotifyERRORBorder = { fg = colors.red },
    NotifyWARNBorder = { fg = colors.yellow },
    NotifyINFOBorder = { fg = colors.lavender },
    NotifyDEBUGBorder = { fg = colors.gray },
    NotifyTRACEBorder = { fg = colors.purple },
    NotifyERRORIcon = { fg = colors.red },
    NotifyWARNIcon = { fg = colors.yellow },
    NotifyINFOIcon = { fg = colors.lavender },
    NotifyDEBUGIcon = { fg = colors.gray },
    NotifyTRACEIcon = { fg = colors.purple },
    NotifyERRORTitle = { fg = colors.red },
    NotifyWARNTitle = { fg = colors.yellow },
    NotifyINFOTitle = { fg = colors.lavender },
    NotifyDEBUGTitle = { fg = colors.gray },
    NotifyTRACETitle = { fg = colors.purple },

    -- Cmp
    CmpItemAbbrDeprecated = { fg = colors.gray, strikethrough = true },
    CmpItemAbbrMatch = { fg = colors.purple, bold = true },
    CmpItemAbbrMatchFuzzy = { fg = colors.purple, bold = true },
    CmpItemKindVariable = { fg = colors.fg },
    CmpItemKindInterface = { fg = colors.yellow },
    CmpItemKindText = { fg = colors.fg },
    CmpItemKindFunction = { fg = colors.purple },
    CmpItemKindMethod = { fg = colors.purple },
    CmpItemKindKeyword = { fg = colors.purple },
    CmpItemKindProperty = { fg = colors.fg },
    CmpItemKindUnit = { fg = colors.yellow },
    CmpItemKindSnippet = { fg = colors.yellow },
    CmpItemKindFile = { fg = colors.fg },
    CmpItemKindFolder = { fg = colors.purple },

    -- Rainbow delimiters (distinct colors for each level)
    RainbowDelimiterRed = { fg = colors.red },
    RainbowDelimiterYellow = { fg = colors.yellow },
    RainbowDelimiterBlue = { fg = "#6be5fd" },  -- Cyan blue
    RainbowDelimiterOrange = { fg = "#ff9e64" }, -- Orange
    RainbowDelimiterViolet = { fg = colors.violet },
    RainbowDelimiterCyan = { fg = "#6be5fd" },
    RainbowDelimiterGreen = { fg = "#9ece6a" },  -- Soft green for variety
  }

  -- Apply highlights
  for group, hl in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, hl)
  end
end

M.colors = colors

return M
