local colors = require "colors"
local settings = require "settings"
local utils = require "utils"

local ui = {}

local theme = settings.theme
local metrics = settings.ui
local sp = settings.layout.spacing
local col = settings.layout.columns
local fnt = settings.layout.fonts

local NO_BG = { drawing = false }

function ui.capsule(opts)
  opts = opts or {}
  return {
    drawing = opts.drawing ~= false,
    color = opts.color or theme.surface,
    border_width = opts.border_width or theme.border_width or metrics.item_border_width,
    border_color = opts.border_color or theme.border,
    corner_radius = opts.corner_radius or metrics.item_corner_radius,
    height = opts.height or metrics.item_height,
  }
end

function ui.icon_pad()
  return { padding_left = metrics.icon_padding_left, padding_right = metrics.icon_padding_right }
end

function ui.label_pad()
  return { padding_left = metrics.label_padding_left, padding_right = metrics.label_padding_right }
end

function ui.rate_font()
  return settings.font.numbers .. ":" .. settings.font.style_map["Bold"] .. ":" .. fnt.rate
end

local function apply_icon_pad(icon)
  if not icon or icon.drawing == false then
    return icon
  end
  if icon.padding_left == nil then
    icon.padding_left = metrics.icon_padding_left
  end
  if icon.padding_right == nil then
    icon.padding_right = metrics.icon_padding_right
  end
  return icon
end

local function apply_center_icon_pad(icon)
  if not icon or icon.drawing == false then
    return icon
  end
  if icon.padding_left == nil then
    icon.padding_left = sp.icon
  end
  if icon.padding_right == nil then
    icon.padding_right = sp.icon
  end
  return icon
end

local function apply_label_pad(label)
  if not label or label.drawing == false then
    return label
  end
  if label.padding_left == nil then
    label.padding_left = metrics.label_padding_left
  end
  if label.padding_right == nil then
    label.padding_right = metrics.label_padding_right
  end
  return label
end

function ui.add_capsule(name, spec)
  spec = spec or {}
  local hidden_label = spec.label and spec.label.drawing == false
  local cfg = {
    position = spec.position or "right",
    padding_left = spec.padding_left ~= nil and spec.padding_left or (spec.widget_gap == false and 0 or sp.widget),
    padding_right = spec.padding_right ~= nil and spec.padding_right or (spec.widget_gap == false and 0 or sp.widget),
    background = ui.capsule(spec.surface),
    icon = hidden_label and apply_center_icon_pad(spec.icon) or apply_icon_pad(spec.icon),
    label = apply_label_pad(spec.label),
    update_freq = spec.update_freq,
    updates = spec.updates,
    popup = spec.popup,
    click_script = spec.click_script,
    drawing = spec.drawing,
  }
  return sbar.add("item", name, cfg)
end

function ui.bracket_icon(name, spec)
  spec = spec or {}
  return sbar.add("item", name, {
    position = "right",
    width = spec.width,
    padding_left = sp.bracket_item,
    padding_right = sp.bracket_item,
    icon = apply_icon_pad(spec.icon),
    label = spec.label or NO_BG,
    background = NO_BG,
  })
end

function ui.bracket_group(name, members, opts)
  opts = opts or {}
  local pad_l = opts.padding_left ~= nil and opts.padding_left or (opts.padding or 0)
  local pad_r = opts.padding_right ~= nil and opts.padding_right or (opts.padding or 0)
  return sbar.add("bracket", name, members, {
    background = ui.capsule {
      color = opts.color or theme.surface_alt,
      border_color = opts.border_color or theme.border,
    },
    padding_left = pad_l,
    padding_right = pad_r,
  })
end

function ui.bracket_spacer(name, width)
  sbar.add("item", name, {
    position = "right",
    width = width,
    padding_left = sp.bracket_item,
    padding_right = sp.bracket_item,
    background = NO_BG,
    icon = NO_BG,
    label = NO_BG,
  })
end

function ui.bracket_metric(name, spec)
  spec = spec or {}
  local icon = {
    font = spec.icon_font or {
      family = fnt.hw_mono,
      style = settings.font.style_map["Bold"],
      size = fnt.hw_small,
    },
    string = spec.icon,
    color = spec.color,
    width = spec.icon_w or col.icon,
    align = "left",
    padding_left = sp.inner,
    padding_right = sp.inner,
  }
  local label = {
    font = spec.label_font or icon.font,
    color = spec.color,
    string = spec.text,
    width = spec.label_w or col.label,
    align = spec.label_align or "right",
  }
  if spec.label_pad_l then
    label.padding_left = spec.label_pad_l
  end
  if spec.label_pad_r then
    label.padding_right = spec.label_pad_r
  end

  return sbar.add("item", name, {
    position = "right",
    padding_left = spec.pad_l or sp.bracket_item,
    padding_right = spec.pad_r or sp.bracket_item,
    width = spec.width,
    icon = spec.icon_hidden and NO_BG or icon,
    label = spec.label_hidden and NO_BG or label,
    y_offset = spec.stack,
    background = NO_BG,
  })
end

function ui.bracket_graph(name, width, spec)
  spec = spec or {}
  return sbar.add("graph", name, width, {
    position = "right",
    padding_left = spec.pad_l or sp.bracket_item,
    padding_right = spec.pad_r or sp.bracket_item,
    y_offset = spec.y,
    graph = spec.graph,
    icon = NO_BG,
    label = NO_BG,
    background = { drawing = false, height = spec.height or settings.layout.hardware.graph_h },
    update_freq = spec.update_freq,
  })
end

function ui.popup_header(name, parent, spec)
  spec = spec or {}
  local pad = ui.icon_pad()
  local label_pad = ui.label_pad()
  return sbar.add("item", name, {
    position = "popup." .. parent.name,
    icon = {
      font = spec.icon_font,
      string = spec.icon,
      padding_left = pad.padding_left,
      padding_right = pad.padding_right,
    },
    width = spec.width,
    align = spec.align or "center",
    label = {
      font = spec.label_font,
      max_chars = spec.max_chars,
      string = spec.label or "",
      align = spec.label_align or "center",
      padding_left = label_pad.padding_left,
      padding_right = label_pad.padding_right,
    },
    background = spec.background,
  })
end

function ui.stacked_rate(name, spec)
  return sbar.add("item", name, {
    position = "right",
    padding_left = spec.padding_left ~= nil and spec.padding_left or sp.stack,
    padding_right = spec.padding_right or 0,
    width = spec.width or 0,
    icon = {
      font = spec.font or ui.rate_font(),
      string = spec.icon,
      color = spec.color,
      width = col.rate_icon,
      align = spec.icon_align or "center",
      padding_left = spec.icon_padding or 2,
      padding_right = spec.icon_padding or 6,
    },
    label = {
      font = spec.font or ui.rate_font(),
      color = spec.color,
      string = spec.text or "000 Bps",
      width = col.rate,
      align = "right",
    },
    y_offset = spec.stack,
    background = NO_BG,
  })
end

function ui.popup_row(height)
  return { height = height or metrics.popup_row_height }
end

function ui.popup_cell()
  return {
    icon = {
      padding_left = metrics.popup_icon_padding,
      padding_right = metrics.popup_icon_padding,
    },
    label = { padding_right = metrics.popup_label_padding },
  }
end

function ui.popup_field(name, parent, spec)
  spec = spec or {}
  local cell = ui.popup_cell()
  local item = {
    position = "popup." .. parent.name,
    icon = {
      string = spec.icon,
      align = spec.icon_align or "left",
      width = spec.icon_width,
      padding_left = cell.icon.padding_left,
      padding_right = cell.icon.padding_right,
      font = spec.icon_font,
    },
    label = {
      string = spec.label or "...",
      align = spec.label_align or "left",
      width = spec.label_width,
      max_chars = spec.max_chars,
      padding_right = cell.label.padding_right,
      font = spec.label_font,
    },
    background = spec.background or ui.popup_row(spec.height),
  }
  if spec.drawing ~= nil then
    item.drawing = spec.drawing
  end
  return sbar.add("item", name, item)
end

function ui.popup_button(name, parent, spec)
  spec = spec or {}
  local pad = ui.label_pad()
  return sbar.add("item", name, {
    position = "popup." .. parent.name,
    align = spec.align or "left",
    width = spec.width,
    icon = spec.icon and apply_icon_pad(spec.icon) or NO_BG,
    label = {
      string = spec.label,
      align = spec.label_align or "left",
      padding_left = pad.padding_left,
      padding_right = pad.padding_right,
      font = spec.font,
    },
    background = ui.button(spec.button),
  })
end

function ui.popup_icon_button(name, parent, spec)
  spec = spec or {}
  return sbar.add("item", name, {
    position = "popup." .. parent.name,
    icon = apply_icon_pad {
      string = spec.icon,
      font = spec.font or { size = 16.0 },
    },
    label = NO_BG,
    width = spec.width or 90,
    align = spec.align or "center",
    background = ui.button {},
  })
end

function ui.popup_list_row(name, parent, spec)
  spec = spec or {}
  return sbar.add("item", name, {
    position = "popup." .. parent.name,
    label = apply_label_pad {
      string = spec.label,
      font = spec.font,
    },
    icon = apply_icon_pad {
      string = spec.icon or "•",
      color = spec.icon_color,
      font = spec.icon_font,
    },
    background = spec.background or ui.popup_row(),
  })
end

function ui.slider_popup(name, parent_name, accent, click_script)
  return sbar.add("slider", name, 100, {
    position = "popup." .. parent_name,
    slider = ui.slider_track(accent),
    background = ui.button {},
    click_script = click_script,
  })
end

function ui.slider_track(accent)
  return {
    highlight_color = accent,
    background = {
      height = 4,
      corner_radius = 2,
      color = colors.surface0,
    },
    knob = { string = "􀀁" },
  }
end

local function handle_popup_click(primary, env, opts)
  if env.BUTTON == "right" and opts.on_right then
    if type(opts.on_right) == "function" then
      opts.on_right()
    else
      sbar.exec(opts.on_right)
    end
    return
  end
  utils.popup_toggle(primary, opts.on_open)
end

function ui.bind_popup(item, opts)
  opts = opts or {}
  item:subscribe("mouse.clicked", function(env)
    handle_popup_click(item, env, opts)
  end)
  item:subscribe("mouse.exited.global", function()
    utils.popup_hide(item)
  end)
end

function ui.bind_popup_group(primary, triggers, opts)
  opts = opts or {}
  for _, item in ipairs(triggers) do
    item:subscribe("mouse.clicked", function(env)
      handle_popup_click(primary, env, opts)
    end)
  end
  primary:subscribe("mouse.exited.global", function()
    utils.popup_hide(primary)
  end)
end

function ui.button(opts)
  opts = opts or {}
  return {
    color = opts.color or theme.button_bg,
    border_width = opts.border_width or theme.border_width,
    border_color = opts.border_color or theme.border,
    corner_radius = opts.corner_radius or 6,
    height = opts.height or metrics.popup_row_height,
  }
end

function ui.popup(accent)
  return {
    border_width = 1,
    corner_radius = metrics.popup_corner_radius,
    border_color = accent or theme.popup_border,
    color = theme.popup_bg,
    shadow = { drawing = true },
  }
end

return ui
