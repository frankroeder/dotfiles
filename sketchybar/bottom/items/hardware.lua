local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"

local cpu_graph_width = 144
local cpu_icon_pad = 28
local cpu_bar_inset = 8
local cpu_graph_alpha = 0.32
-- Shift the eCPU overlay over the CPU graph column (skip icon + bar inset, fixed label width).
local cpu_overlay_pad = cpu_icon_pad + cpu_bar_inset + settings.hardware.label_width

local hw_label_font = {
  family = settings.font.numbers,
  style = settings.font.style_map["Semibold"],
  size = 10.0,
}

local function fmt_cpu_label(ecpu, pcpu, temp)
  return string.format(
    "eCPU %02d%% pCPU %02d%% %02d°C",
    math.floor(ecpu),
    math.floor(pcpu),
    math.floor(temp)
  )
end

local function fmt_ram_label(ram, swap)
  return string.format("RAM %02d%% SWP %02d%%", math.floor(ram), math.floor(swap))
end

local function fmt_gpu_label(gpu, temp)
  return string.format("GPU %02d%% %02d°C", math.floor(gpu), math.floor(temp))
end

local gpu = sbar.add("graph", "widgets.gpu", 80, {
  position = "right",
  graph = { color = colors.with_alpha(settings.theme.accent, 0.40) },
  icon = {
    string = icons.gpu,
    color = settings.theme.accent,
    padding_left = 4,
    y_offset = 0,
  },
  label = {
    string = fmt_gpu_label(0, 0),
    font = hw_label_font,
    align = "right",
    width = 0,
    padding_right = 4,
    y_offset = 6,
  },
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = colors.with_alpha(settings.theme.accent, 0.42),
  },
})

local ram_g = sbar.add("graph", "widgets.ram", 108, {
  position = "right",
  icon = {
    string = icons.ram,
    color = settings.theme.warn,
    padding_left = 4,
    y_offset = 0,
  },
  label = {
    string = fmt_ram_label(0, 0),
    font = hw_label_font,
    align = "right",
    width = 0,
    padding_right = 4,
    y_offset = 6,
  },
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = colors.with_alpha(settings.theme.warn, 0.45),
  },
})

local cpu = sbar.add("graph", "widgets.cpu", cpu_graph_width, {
  position = "right",
  graph = {
    color = colors.with_alpha(colors.blue, cpu_graph_alpha),
    fill_color = colors.with_alpha(colors.blue, cpu_graph_alpha),
  },
  icon = {
    string = icons.cpu,
    color = settings.theme.accent_alt,
    padding_left = 4,
    padding_right = 4,
    y_offset = 0,
  },
  label = {
    string = fmt_cpu_label(0, 0, 0),
    font = hw_label_font,
    align = "right",
    width = 0,
    padding_left = 6,
    padding_right = 4,
    y_offset = 6,
  },
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = colors.with_alpha(settings.theme.accent_alt, 0.42),
  },
  update_freq = settings.hardware.update_freq,
})

local ecpu = sbar.add("graph", "widgets.ecpu", cpu_graph_width, {
  position = "right",
  graph = {
    color = colors.with_alpha(colors.green, cpu_graph_alpha),
    fill_color = colors.with_alpha(colors.green, cpu_graph_alpha),
  },
  background = ui.capsule {
    color = colors.transparent,
    border_width = 0,
  },
  icon = { drawing = false },
  label = { drawing = false },
  padding_right = -cpu_overlay_pad,
})

local power = sbar.add("item", "widgets.power", {
  position = "right",
  icon = {
    string = icons.power,
    color = settings.theme.warn,
    padding_left = 2,
    padding_right = -1,
  },
  label = {
    string = "-- W",
    font = {
      size = 10.0,
    },
    padding_right = 3,
  },
  padding_right = 20,
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = colors.with_alpha(settings.theme.warn, 0.45),
  },
})

cpu:subscribe("routine", function(env)
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
    local cpu_temp = output.temperature.cpu_avg_c
    local ram_total = output.memory.ram_gb_total
    local ram_used = output.memory.ram_gb_used
    local swap_total = output.memory.swap_gb_total
    local swap_used = output.memory.swap_gb_used
    local gpu_used = math.floor(output.usage.gpu.active_percent)
    local gpu_temp = output.temperature.gpu_avg_c
    if
      not (
        ecpu_val
        and pcpu_val
        and cpu_temp
        and ram_total
        and ram_used
        and swap_total
        and swap_used
        and gpu_used
        and gpu_temp
      )
    then
      return
    end

    local ram_pct = (ram_used / ram_total) * 100
    local swap_pct = (swap_total > 0) and ((swap_used / swap_total) * 100) or 0
    local color_ram = utils.color_gradient(ram_pct)
    local color_gpu = utils.color_gradient(gpu_used)

    cpu:set {
      graph = {
        color = colors.with_alpha(colors.blue, cpu_graph_alpha),
        fill_color = colors.with_alpha(colors.blue, cpu_graph_alpha),
      },
      label = fmt_cpu_label(ecpu_val, pcpu_val, cpu_temp),
    }
    ecpu:set {
      graph = {
        color = colors.with_alpha(colors.green, cpu_graph_alpha),
        fill_color = colors.with_alpha(colors.green, cpu_graph_alpha),
      },
    }
    ram_g:set {
      graph = { color = colors.with_alpha(color_ram, 0.5) },
      label = fmt_ram_label(ram_pct, swap_pct),
    }
    gpu:set {
      graph = { color = colors.with_alpha(color_gpu, 0.5) },
      label = fmt_gpu_label(gpu_used, gpu_temp),
    }
    power:set {
      label = math.floor(output.power.all_watts or 0) .. " W",
    }

    cpu:push { pcpu_val / 100. }
    ecpu:push { ecpu_val / 100. }
    ram_g:push { ram_pct / 100. }
    gpu:push { gpu_used / 100. }
  end)
end)

cpu:subscribe("mouse.clicked", function(_)
  sbar.exec "open -a 'Activity Monitor'"
end)
