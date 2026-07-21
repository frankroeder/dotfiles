local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"

local sp = settings.layout.spacing
local col = settings.layout.columns
local hw = settings.layout.hardware
local fnt = settings.layout.fonts

local hw_label_font = {
  family = settings.font.family,
  style = settings.font.style_map["Semibold"],
  size = fnt.hw_label,
}

local function clamp_percent(value)
  return math.min(math.max(math.floor(value or 0), 0), 99)
end

local function percent_label(prefix, value)
  return string.format("%s %02d%%", prefix, clamp_percent(value))
end

local function temp_label(value)
  return string.format("%02d°C", math.min(math.max(math.floor(value or 0), 0), 99))
end

local gpu_temp = ui.bracket_metric("widgets.gpu_temp", {
  pad_l = hw.gpu_temp_pad_l,
  color = settings.theme.accent,
  text = "00°C",
  label_font = hw_label_font,
  label_align = "center",
  label_pad_l = sp.inner,
  label_pad_r = sp.edge,
  icon_hidden = true,
})

local gpu_graph = ui.bracket_graph("widgets.gpu_graph", hw.gpu_graph, {
  pad_r = sp.inner,
  y = hw.graph_y,
  graph = {
    color = colors.with_alpha(settings.theme.accent, 0.40),
    line_width = 1.0,
  },
})

local gpu_label = ui.bracket_metric("widgets.gpu_label", {
  pad_r = hw.gpu_label_pad_r,
  width = 78,
  icon = icons.gpu,
  icon_w = 28,
  icon_font = { size = fnt.hw_small },
  color = settings.theme.accent,
  text = "GPU 00%",
})

ui.bracket_spacer("widgets.spacer_gpu_ram", 0)

local ram_top = ui.bracket_metric("widgets.ram_top", {
  width = hw.ram_top_w,
  icon = icons.ram,
  color = settings.theme.warn,
  text = "RAM 00%",
  label_pad_r = sp.edge,
  stack = sp.stack,
})

local ram_bot = ui.bracket_metric("widgets.ram_bot", {
  width = hw.ram_bot_w,
  icon = icons.swap,
  color = settings.theme.warn,
  text = "SWP 00%",
  label_pad_r = sp.edge,
  stack = -sp.stack,
})

ui.bracket_spacer("widgets.spacer_ram_cpu", sp.group)

local cpu_temp = ui.bracket_metric("widgets.cpu_temp", {
  color = settings.theme.accent_alt,
  text = "00°C",
  label_font = hw_label_font,
  label_align = "center",
  label_pad_l = sp.inner,
  label_pad_r = sp.edge,
  icon_hidden = true,
})

local cpu_pcpu_graph = ui.bracket_graph("widgets.cpu_pcpu", hw.cpu_graph, {
  pad_l = sp.inner,
  pad_r = sp.inner,
  y = hw.graph_y,
  update_freq = settings.hardware.update_freq,
  graph = {
    color = colors.with_alpha(colors.blue, hw.graph_alpha),
    fill_color = colors.with_alpha(colors.blue, hw.graph_alpha),
    line_width = 1.0,
  },
})

local cpu_ecpu_graph = ui.bracket_graph("widgets.cpu_ecpu", hw.cpu_graph, {
  pad_l = hw.cpu_ecpu_pad_l,
  pad_r = -(hw.cpu_graph + hw.cpu_ecpu_pad_r_extra),
  y = hw.ecpu_graph_y,
  graph = {
    color = colors.with_alpha(colors.green, hw.graph_alpha),
    fill_color = colors.with_alpha(colors.green, hw.graph_alpha),
    line_width = 1.0,
  },
})

local cpu_ecpu_label = ui.bracket_metric("widgets.cpu_ecpu_label", {
  width = hw.cpu_ecpu_w,
  icon = icons.cpu,
  icon_w = col.icon_sm,
  color = colors.green,
  text = "eCPU 00%",
  label_w = col.label_lg,
  stack = sp.stack,
})

local cpu_pcpu_label = ui.bracket_metric("widgets.cpu_pcpu_label", {
  width = hw.cpu_pcpu_w,
  icon = icons.cpu,
  icon_w = col.icon_sm,
  color = colors.blue,
  text = "pCPU 00%",
  label_w = col.label_lg,
  stack = -sp.stack,
})

ui.bracket_spacer("widgets.spacer_cpu_power", sp.group)

local power = ui.add_capsule("widgets.power", {
  padding_right = 0,
  surface = {
    color = settings.theme.surface_alt,
    border_color = settings.theme.border,
  },
  icon = {
    string = icons.power,
    color = settings.theme.warn,
    padding_left = 4,
    padding_right = 4,
  },
  label = {
    string = "-- W",
    font = { size = 12.0 },
    padding_left = 0,
    padding_right = 6,
  },
})

ui.bracket_group("hw.group.gpu", { "widgets.gpu_label", "widgets.gpu_graph", "widgets.gpu_temp" })
ui.bracket_group("hw.group.ram", { "widgets.ram_top", "widgets.ram_bot" })
ui.bracket_group("hw.group.cpu", {
  "widgets.cpu_ecpu_label",
  "widgets.cpu_pcpu_label",
  "widgets.cpu_pcpu",
  "widgets.cpu_ecpu",
  "widgets.cpu_temp",
})

local function apply_silistats(output)
  if not output or not output.usage or not output.temperature or not output.memory then
    return
  end

  if not output.usage.ecpu or not output.usage.pcpu or not output.usage.gpu then
    return
  end

  local ecpu_val = math.floor(output.usage.ecpu.active_percent or 0)
  local pcpu_val = math.floor(output.usage.pcpu.active_percent or 0)
  local cpu_t = output.temperature.cpu_avg_c
  local ram_total = output.memory.ram_gb_total
  local ram_used = output.memory.ram_gb_used
  local swap_total = output.memory.swap_gb_total
  local swap_used = output.memory.swap_gb_used
  local gpu_used = math.floor(output.usage.gpu.active_percent or 0)
  local gpu_t = output.temperature.gpu_avg_c

  if
    not (ram_total and ram_used and swap_total and swap_used and cpu_t and gpu_t)
    or ram_total == 0
  then
    return
  end

  local ram_pct = (ram_used / ram_total) * 100
  local swap_pct = (swap_total > 0) and ((swap_used / swap_total) * 100) or 0
  local color_ram = utils.color_gradient(ram_pct)
  local color_gpu = utils.color_gradient(gpu_used)
  local color_ecpu = utils.color_gradient(ecpu_val)
  local color_pcpu = utils.color_gradient(pcpu_val)

  cpu_ecpu_label:set {
    icon = { color = color_ecpu },
    label = { string = percent_label("eCPU", ecpu_val), color = color_ecpu },
  }
  cpu_pcpu_label:set {
    icon = { color = color_pcpu },
    label = { string = percent_label("pCPU", pcpu_val), color = color_pcpu },
  }
  local theme = settings.theme
  cpu_temp:set { label = { string = temp_label(cpu_t), color = theme.accent_alt } }

  ram_top:set {
    icon = { color = color_ram },
    label = { string = percent_label("RAM", ram_pct), color = color_ram },
  }
  ram_bot:set {
    icon = { color = theme.warn },
    label = { string = percent_label("SWP", swap_pct), color = theme.warn },
  }

  gpu_label:set {
    label = { string = percent_label("GPU", gpu_used), color = color_gpu },
    icon = { color = color_gpu },
  }
  gpu_temp:set { label = { string = temp_label(gpu_t), color = theme.accent } }
  gpu_graph:set { graph = { color = colors.with_alpha(color_gpu, 0.5) } }

  local power_watts = output.power and output.power.all_watts or 0
  power:set { label = { string = string.format("%02d W", math.min(99, math.floor(power_watts))) } }

  cpu_pcpu_graph:push { pcpu_val / 100. * 0.275 }
  cpu_ecpu_graph:push { ecpu_val / 100. * 0.275 }
  gpu_graph:push { gpu_used / 100. * 0.6 }

  cpu_pcpu_graph:set {
    graph = {
      color = colors.with_alpha(color_pcpu, hw.graph_alpha),
      fill_color = colors.with_alpha(color_pcpu, hw.graph_alpha),
    },
  }
  cpu_ecpu_graph:set {
    graph = {
      color = colors.with_alpha(color_ecpu, hw.graph_alpha),
      fill_color = colors.with_alpha(color_ecpu, hw.graph_alpha),
    },
  }
end

local function poll_silistats()
  sbar.exec(settings.hardware.silistats_path .. " --once", apply_silistats)
end

cpu_pcpu_graph:subscribe({ "routine", "deferred_wake" }, poll_silistats)

cpu_pcpu_graph:subscribe("mouse.clicked", function()
  sbar.exec "open -a 'Activity Monitor'"
end)

power:subscribe("mouse.clicked", function()
  sbar.exec "open -a 'Activity Monitor'"
end)

local function refresh_theme()
  local theme = settings.theme
  local bracket_bg = ui.capsule {
    color = theme.surface_alt,
    border_color = theme.border,
  }

  -- Brackets + static metric colors; silistats repaints gradient metrics.
  cpu_temp:set { label = { color = theme.accent_alt } }
  gpu_temp:set { label = { color = theme.accent } }
  ram_bot:set { icon = { color = theme.warn }, label = { color = theme.warn } }
  power:set {
    background = ui.capsule {
      color = theme.surface_alt,
      border_color = theme.border,
    },
    icon = { color = theme.warn },
    label = { color = theme.text_muted },
  }
  sbar.set("hw.group.gpu", { background = bracket_bg })
  sbar.set("hw.group.ram", { background = bracket_bg })
  sbar.set("hw.group.cpu", { background = bracket_bg })
  poll_silistats()
end

cpu_pcpu_graph:subscribe("theme_colors_updated", refresh_theme)
