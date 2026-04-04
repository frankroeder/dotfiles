local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"

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
    string = "GPU --% --°C",
    font = {
      size = 9.0,
    },
    align = "right",
    width = 0,
    padding_right = 4,
    y_offset = 8,
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
    string = "RAM --% SWAP --%",
    font = {
      size = 9.0,
    },
    align = "right",
    width = 0,
    padding_right = 4,
    y_offset = 8,
  },
  background = {
    drawing = true,
    color = settings.theme.surface_alt,
    border_width = 0,
    corner_radius = settings.ui.item_corner_radius,
    height = settings.ui.item_height,
  },
})

local cpu = sbar.add("graph", "widgets.cpu", 138, {
  position = "right",
  icon = {
    string = icons.cpu,
    color = settings.theme.accent_alt,
    padding_left = 4,
    y_offset = 0,
  },
  label = {
    string = "eCPU --% pCPU --% --°C",
    font = {
      size = 9.0,
    },
    align = "right",
    width = 0,
    padding_right = 4,
    y_offset = 8,
  },
  background = {
    drawing = true,
    color = settings.theme.surface_alt,
    border_width = 0,
    corner_radius = settings.ui.item_corner_radius,
    height = settings.ui.item_height,
  },
  update_freq = settings.hardware.update_freq,
})

local ecpu = sbar.add("graph", "widgets.ecpu", 138, {
  position = "right",
  graph = { color = colors.with_alpha(colors.green, 0.5) },
  background = { drawing = false },
  icon = { drawing = false },
  label = { drawing = false },
  padding_right = -163,
  y_offset = 4,
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
      size = 9.0,
    },
    padding_right = 3,
  },
  padding_right = 23,
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
    print(
      ecpu_val,
      pcpu_val,
      cpu_temp,
      ram_total,
      ram_used,
      swap_total,
      swap_used,
      gpu_used,
      gpu_temp
    )

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
      graph = { color = colors.with_alpha(colors.blue, 0.5) },
      label = "eCPU " .. ecpu_val .. "% pCPU " .. pcpu_val .. "% " .. math.floor(cpu_temp) .. "°C",
    }
    ram_g:set {
      graph = { color = colors.with_alpha(color_ram, 0.5) },
      label = "RAM " .. math.floor(ram_pct) .. "% SWAP " .. math.floor(swap_pct) .. "%",
    }
    gpu:set {
      graph = { color = colors.with_alpha(color_gpu, 0.5) },
      label = "GPU " .. gpu_used .. "% " .. math.floor(gpu_temp) .. "°C",
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
