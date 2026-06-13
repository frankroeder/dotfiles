local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"

local cpu_graph_width = 60
local gpu_graph_width = 30
local graph_alpha = 0.32
local graph_height = 22

local hw_label_font = {
  family = settings.font.numbers,
  style = settings.font.style_map["Semibold"],
  size = 14.0,
}

local hw_small_font = {
  family = settings.font.numbers,
  style = settings.font.style_map["Bold"],
  size = 11.0,
}

-- GPU: label | graph | temp
local gpu_temp = sbar.add("item", "widgets.gpu_temp", {
  position = "right",
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    font = hw_label_font,
    string = "00°C",
    color = settings.theme.accent,
    align = "center",
    padding_left = 4,
    padding_right = 6,
  },
  background = { drawing = false },
})

local gpu_graph = sbar.add("graph", "widgets.gpu_graph", gpu_graph_width, {
  position = "right",
  padding_left = 0,
  padding_right = 4,
  y_offset = 8,
  graph = {
    color = colors.with_alpha(settings.theme.accent, 0.40),
    line_width = 1.0,
  },
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false, height = graph_height },
})

local gpu_label = sbar.add("item", "widgets.gpu_label", {
  position = "right",
  padding_left = 0,
  width = 80,
  icon = {
    font = hw_small_font,
    string = icons.gpu,
    color = settings.theme.accent,
    width = 28,
    align = "left",
    padding_left = 4,
    padding_right = 2,
  },
  label = {
    font = hw_small_font,
    color = settings.theme.accent,
    string = "GPU 00%",
    width = 54,
    align = "right",
  },
  background = { drawing = false },
})

sbar.add("item", "widgets.spacer_gpu_ram", {
  position = "right",
  width = 16,
  background = { drawing = false },
  icon = { drawing = false },
  label = { drawing = false },
  padding_left = 0,
  padding_right = 0,
})

-- RAM: text-only stacked
local ram_top = sbar.add("item", "widgets.ram_top", {
  position = "right",
  padding_left = 0,
  width = 0,
  icon = {
    font = hw_small_font,
    string = icons.ram,
    color = settings.theme.warn,
    width = 28,
    align = "left",
    padding_left = 4,
    padding_right = 2,
  },
  label = {
    font = hw_small_font,
    color = settings.theme.warn,
    string = "RAM 00%",
    width = 62,
    align = "right",
    padding_right = 6,
  },
  y_offset = 6,
  background = { drawing = false },
})

local ram_bot = sbar.add("item", "widgets.ram_bot", {
  position = "right",
  padding_left = 0,
  width = 88,
  icon = {
    font = hw_small_font,
    string = icons.swap,
    color = settings.theme.warn,
    width = 28,
    align = "left",
    padding_left = 4,
    padding_right = 2,
  },
  label = {
    font = hw_small_font,
    color = settings.theme.warn,
    string = "SWP 00%",
    width = 62,
    align = "right",
    padding_right = 6,
  },
  y_offset = -6,
  background = { drawing = false },
})

sbar.add("item", "widgets.spacer_ram_cpu", {
  position = "right",
  width = 16,
  background = { drawing = false },
  icon = { drawing = false },
  label = { drawing = false },
  padding_left = 0,
  padding_right = 0,
})

-- CPU temp
local cpu_temp = sbar.add("item", "widgets.cpu_temp", {
  position = "right",
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    font = hw_label_font,
    string = "00°C",
    color = settings.theme.accent_alt,
    align = "center",
    padding_left = 4,
    padding_right = 6,
  },
  background = { drawing = false },
})

-- CPU graphs (pCPU behind, eCPU overlay)
local cpu_pcpu_graph = sbar.add("graph", "widgets.cpu_pcpu", cpu_graph_width, {
  position = "right",
  padding_left = 4,
  padding_right = 4,
  y_offset = 8,
  graph = {
    color = colors.with_alpha(colors.blue, graph_alpha),
    fill_color = colors.with_alpha(colors.blue, graph_alpha),
    line_width = 1.0,
  },
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false, height = graph_height },
  update_freq = settings.hardware.update_freq,
})

local cpu_ecpu_graph = sbar.add("graph", "widgets.cpu_ecpu", cpu_graph_width, {
  position = "right",
  padding_left = 0,
  padding_right = -(cpu_graph_width + 4),
  y_offset = 21,
  graph = {
    color = colors.with_alpha(colors.green, graph_alpha),
    fill_color = colors.with_alpha(colors.green, graph_alpha),
    line_width = 1.0,
  },
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false, height = graph_height },
})

-- CPU labels: stacked eCPU top / pCPU bottom
local cpu_ecpu_label = sbar.add("item", "widgets.cpu_ecpu_label", {
  position = "right",
  padding_left = 0,
  width = 0,
  icon = {
    font = hw_small_font,
    string = icons.cpu,
    color = colors.green,
    width = 22,
    align = "left",
    padding_left = 4,
    padding_right = 2,
  },
  label = {
    font = hw_small_font,
    color = colors.green,
    string = "eCPU 00%",
    width = 68,
    align = "right",
  },
  y_offset = 6,
  background = { drawing = false },
})

local cpu_pcpu_label = sbar.add("item", "widgets.cpu_pcpu_label", {
  position = "right",
  padding_left = 0,
  width = 88,
  icon = {
    font = hw_small_font,
    string = icons.cpu,
    color = colors.blue,
    width = 22,
    align = "left",
    padding_left = 4,
    padding_right = 2,
  },
  label = {
    font = hw_small_font,
    color = colors.blue,
    string = "pCPU 00%",
    width = 68,
    align = "right",
  },
  y_offset = -6,
  background = { drawing = false },
})

sbar.add("item", "widgets.spacer_cpu_power", {
  position = "right",
  width = 16,
  background = { drawing = false },
  icon = { drawing = false },
  label = { drawing = false },
  padding_left = 0,
  padding_right = 0,
})

-- Power widget
local power = sbar.add("item", "widgets.power", {
  position = "right",
  icon = {
    string = icons.power,
    color = settings.theme.warn,
    padding_left = 4,
    padding_right = 2,
  },
  label = {
    string = "-- W",
    font = { size = 10.0 },
    padding_right = 4,
  },
  padding_right = 5,
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = settings.theme.border,
  },
})

-- Bracket groups with capsule backgrounds
sbar.add("bracket", "hw.group.gpu", {
  "widgets.gpu_label",
  "widgets.gpu_graph",
  "widgets.gpu_temp",
}, {
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = settings.theme.border,
  },
})

sbar.add("bracket", "hw.group.ram", {
  "widgets.ram_top",
  "widgets.ram_bot",
}, {
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = settings.theme.border,
  },
})

sbar.add("bracket", "hw.group.cpu", {
  "widgets.cpu_ecpu_label",
  "widgets.cpu_pcpu_label",
  "widgets.cpu_pcpu",
  "widgets.cpu_ecpu",
  "widgets.cpu_temp",
}, {
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = settings.theme.border,
  },
})

-- Routine update
cpu_pcpu_graph:subscribe("routine", function(env)
  sbar.exec(settings.hardware.silistats_path .. " --once", function(output)
    if
      not output
      or not output.usage.ecpu.active_percent
      or not output.usage.pcpu.active_percent
      or not output.temperature
      or not output.memory
      or not output.usage.gpu.active_percent
    then
      return
    end
    local ecpu_val = math.floor(output.usage.ecpu.active_percent)
    local pcpu_val = math.floor(output.usage.pcpu.active_percent)
    local cpu_t = output.temperature.cpu_avg_c
    local ram_total = output.memory.ram_gb_total
    local ram_used = output.memory.ram_gb_used
    local swap_total = output.memory.swap_gb_total
    local swap_used = output.memory.swap_gb_used
    local gpu_used = math.floor(output.usage.gpu.active_percent)
    local gpu_t = output.temperature.gpu_avg_c
    if
      not (
        ecpu_val
        and pcpu_val
        and cpu_t
        and ram_total
        and ram_used
        and swap_total
        and swap_used
        and gpu_used
        and gpu_t
      )
    then
      return
    end

    local ram_pct = (ram_used / ram_total) * 100
    local swap_pct = (swap_total > 0) and ((swap_used / swap_total) * 100) or 0
    local color_ram = utils.color_gradient(ram_pct)
    local color_gpu = utils.color_gradient(gpu_used)

    -- CPU
    cpu_ecpu_label:set { label = { string = string.format("eCPU %02d%%", ecpu_val) } }
    cpu_pcpu_label:set { label = { string = string.format("pCPU %02d%%", pcpu_val) } }
    cpu_temp:set { label = { string = string.format("%02d°C", math.floor(cpu_t)) } }

    -- RAM
    ram_top:set {
      icon = { color = color_ram },
      label = { string = string.format("RAM %02d%%", math.floor(ram_pct)), color = color_ram },
    }
    ram_bot:set {
      label = { string = string.format("SWP %02d%%", math.floor(swap_pct)) },
    }

    -- GPU
    gpu_label:set {
      label = { string = string.format("GPU %02d%%", gpu_used), color = color_gpu },
      icon = { color = color_gpu },
    }
    gpu_temp:set { label = { string = string.format("%02d°C", math.floor(gpu_t)) } }
    gpu_graph:set { graph = { color = colors.with_alpha(color_gpu, 0.5) } }

    -- Power
    power:set { label = math.floor(output.power.all_watts or 0) .. " W" }

    -- Push graph data and scale graphs by 0.6
    cpu_pcpu_graph:push { pcpu_val / 100. * .275 }
    cpu_ecpu_graph:push { ecpu_val / 100. * .275 }
    gpu_graph:push { gpu_used / 100. * .6 }
  end)
end)

cpu_pcpu_graph:subscribe("mouse.clicked", function(_)
  sbar.exec "open -a 'Activity Monitor'"
end)
