return {
  {
    "RRethy/base16-nvim",
    priority = 1000,
    config = function()
      local p = {
        mode = "{{mode}}",
        bg = "{{colors.background.default.hex}}",
        fg = "{{colors.on_surface.default.hex}}",
        fg_alt = "{{colors.on_surface_variant.default.hex}}",
        surface = "{{colors.surface.default.hex}}",
        surface_low = "{{colors.surface_container_low.default.hex}}",
        surface_high = "{{colors.surface_container_high.default.hex}}",
        surface_highest = "{{colors.surface_container_highest.default.hex}}",
        border = "{{colors.outline_variant.default.hex}}",
        muted = "{{colors.outline.default.hex}}",
        primary = "{{colors.primary.default.hex}}",
        on_primary = "{{colors.on_primary.default.hex}}",
        primary_container = "{{colors.primary_container.default.hex}}",
        on_primary_container = "{{colors.on_primary_container.default.hex}}",
        secondary = "{{colors.secondary.default.hex}}",
        tertiary = "{{colors.tertiary.default.hex}}",
        error = "{{colors.error.default.hex}}",
        red = "{{colors.error.default.hex}}",
        orange = "{{colors.tertiary.default.hex}}",
        yellow = "{{colors.tertiary.default.hex}}",
        green = "{{colors.secondary.default.hex}}",
        cyan = "{{colors.secondary.default.hex}}",
        blue = "{{colors.primary.default.hex}}",
        magenta = "{{colors.tertiary.default.hex}}",
      }

      local function hi(name, opts)
        vim.api.nvim_set_hl(0, name, opts)
      end

      local semantic = p.mode == "light" and {
        red = p.error,
        yellow = "#765d00",
        green = "#2f6b36",
        blue = "#3d5f8f",
      } or {
        red = p.error,
        yellow = "#e5c463",
        green = "#8bd17c",
        blue = "#9bbcff",
      }

      vim.o.background = p.mode
      vim.o.termguicolors = true
      vim.g.colors_name = "dankcolors"

      require("base16-colorscheme").setup({
        base00 = p.bg,
        base01 = p.surface_low,
        base02 = p.surface_high,
        base03 = p.muted,
        base04 = p.fg_alt,
        base05 = p.fg,
        base06 = p.fg,
        base07 = p.fg,
        base08 = p.red,
        base09 = p.orange,
        base0A = p.yellow,
        base0B = p.green,
        base0C = p.cyan,
        base0D = p.primary,
        base0E = p.tertiary,
        base0F = p.secondary,
      })

      hi("Normal", { fg = p.fg, bg = p.bg })
      hi("NormalNC", { fg = p.fg, bg = p.bg })
      hi("NormalFloat", { fg = p.fg, bg = p.surface_low })
      hi("FloatBorder", { fg = p.border, bg = p.surface_low })
      hi("FloatTitle", { fg = p.primary, bg = p.surface_low, bold = true })
      hi("Cursor", { bg = p.primary })
      hi("CursorLine", { bg = p.surface_low })
      hi("CursorLineNr", { fg = p.primary, bold = true })
      hi("LineNr", { fg = p.muted })
      hi("SignColumn", { bg = p.bg })
      hi("EndOfBuffer", { fg = p.bg, bg = p.bg })
      hi("WinSeparator", { fg = p.border })
      hi("StatusLine", { fg = p.fg, bg = p.surface_low })
      hi("StatusLineNC", { fg = p.fg_alt, bg = p.bg })
      hi("Pmenu", { fg = p.fg, bg = p.surface_low })
      hi("PmenuSel", { fg = p.on_primary_container, bg = p.primary_container, bold = true })
      hi("Visual", { fg = p.on_primary_container, bg = p.primary_container })
      hi("Search", { fg = p.on_primary_container, bg = p.primary_container, bold = true })
      hi("IncSearch", { fg = p.on_primary, bg = p.primary, bold = true })
      hi("MatchParen", { fg = p.primary, bg = p.surface_high, bold = true })

      hi("Comment", { fg = p.muted, italic = true })
      hi("String", { fg = p.green })
      hi("Character", { fg = p.green })
      hi("Number", { fg = p.orange })
      hi("Float", { fg = p.orange })
      hi("Boolean", { fg = p.tertiary, bold = true })
      hi("Constant", { fg = p.tertiary, bold = true })
      hi("Identifier", { fg = p.fg })
      hi("Function", { fg = p.primary, bold = true })
      hi("Statement", { fg = p.tertiary, bold = true })
      hi("Keyword", { link = "Statement" })
      hi("Repeat", { link = "Statement" })
      hi("Conditional", { link = "Statement" })
      hi("Operator", { fg = p.fg_alt })
      hi("Delimiter", { fg = p.fg_alt })
      hi("Type", { fg = p.secondary, bold = true, italic = true })
      hi("Structure", { link = "Type" })
      hi("PreProc", { fg = p.cyan })
      hi("Macro", { fg = p.cyan, italic = true })
      hi("Special", { fg = p.primary })
      hi("Todo", { fg = p.primary, bold = true })

      hi("@variable", { fg = p.fg })
      hi("@variable.builtin", { fg = p.primary, italic = true })
      hi("@variable.member", { fg = p.fg_alt })
      hi("@constant", { link = "Constant" })
      hi("@string", { link = "String" })
      hi("@number", { link = "Number" })
      hi("@boolean", { link = "Boolean" })
      hi("@type", { link = "Type" })
      hi("@function", { link = "Function" })
      hi("@function.call", { fg = p.primary })
      hi("@function.method", { fg = p.primary })
      hi("@function.method.call", { fg = p.primary })
      hi("@function.macro", { link = "Macro" })
      hi("@keyword", { link = "Statement" })
      hi("@keyword.import", { fg = p.cyan, bold = true })
      hi("@operator", { fg = p.fg_alt })
      hi("@punctuation.bracket", { link = "Delimiter" })
      hi("@punctuation.delimiter", { link = "Delimiter" })
      hi("@comment", { link = "Comment" })
      hi("@property", { fg = p.fg_alt })
      hi("@constructor", { link = "Type" })
      hi("@markup.heading", { fg = p.primary, bold = true })
      hi("@markup.link", { fg = p.primary, underline = true })
      hi("@markup.raw", { fg = p.green })

      hi("DiagnosticError", { fg = semantic.red })
      hi("DiagnosticWarn", { fg = semantic.yellow })
      hi("DiagnosticInfo", { fg = semantic.blue })
      hi("DiagnosticHint", { fg = p.cyan })
      hi("DiagnosticOk", { fg = semantic.green })
      hi("DiagnosticUnderlineError", { sp = semantic.red, undercurl = true })
      hi("DiagnosticUnderlineWarn", { sp = semantic.yellow, undercurl = true })
      hi("DiagnosticUnderlineInfo", { sp = semantic.blue, undercurl = true })
      hi("DiagnosticUnderlineHint", { sp = p.cyan, undercurl = true })

      hi("GitSignsAdd", { fg = semantic.green })
      hi("GitSignsChange", { fg = semantic.yellow })
      hi("GitSignsDelete", { fg = semantic.red })
      hi("Added", { fg = semantic.green })
      hi("Changed", { fg = semantic.yellow })
      hi("Removed", { fg = semantic.red })

      hi("BlinkCmpMenu", { fg = p.fg, bg = p.surface_low })
      hi("BlinkCmpMenuSelection", { fg = p.on_primary_container, bg = p.primary_container, bold = true })
      hi("BlinkCmpMenuBorder", { fg = p.border, bg = p.surface_low })
      hi("BlinkCmpLabelMatch", { fg = p.primary, bold = true })
      hi("SnacksPicker", { fg = p.fg, bg = p.bg })
      hi("SnacksPickerBorder", { fg = p.border, bg = p.bg })
      hi("SnacksPickerInput", { fg = p.fg, bg = p.surface_low })
      hi("SnacksPickerInputBorder", { fg = p.primary, bg = p.surface_low })
      hi("SnacksPickerMatch", { fg = p.primary, bold = true })
      hi("SnacksPickerSelected", { fg = p.on_primary_container, bg = p.primary_container, bold = true })
      hi("OilDir", { fg = p.primary, bold = true })
      hi("OilFile", { fg = p.fg })

      vim.g.terminal_color_0 = p.bg
      vim.g.terminal_color_1 = semantic.red
      vim.g.terminal_color_2 = semantic.green
      vim.g.terminal_color_3 = semantic.yellow
      vim.g.terminal_color_4 = semantic.blue
      vim.g.terminal_color_5 = p.tertiary
      vim.g.terminal_color_6 = p.secondary
      vim.g.terminal_color_7 = p.fg_alt
      vim.g.terminal_color_8 = p.muted
      vim.g.terminal_color_9 = semantic.red
      vim.g.terminal_color_10 = semantic.green
      vim.g.terminal_color_11 = semantic.yellow
      vim.g.terminal_color_12 = semantic.blue
      vim.g.terminal_color_13 = p.tertiary
      vim.g.terminal_color_14 = p.secondary
      vim.g.terminal_color_15 = p.fg
    end,
  },
}
