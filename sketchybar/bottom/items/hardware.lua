local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"

local gpu = sbar.add("graph", "widgets.gpu", 80, {
  position = "right",
  graph = { color = colors.with_alpha(colors.blue, 0.5) },
  icon = {
    string = icons.gpu,
    color = colors.blue,
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
})

local ram_g = sbar.add("graph", "widgets.ram", 108, {
  position = "right",
  icon = {
    string = icons.ram,
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
  },
})

local cpu = sbar.add("graph", "widgets.cpu", 138, {
  position = "right",
  icon = {
    string = icons.cpu,
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
    color = colors.yellow,
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
})

cpu:subscribe("routine", function(env)
  sbar.exec(settings.hardware.macmon_path .. " pipe -s 1", function(output)
    if
      not output
      or not output.ecpu_usage
      or not output.pcpu_usage
      or not output.temp
      or not output.memory
      or not output.gpu_usage
    then
      return
    end
    local ecpu_val = math.floor(output.ecpu_usage[2] * 100)
    local pcpu_val = math.floor(output.pcpu_usage[2] * 100)
    local cpu_temp = output.temp.cpu_temp_avg
    local ram_total = output.memory.ram_total
    local ram_used = output.memory.ram_usage
    local swap_total = output.memory.swap_total
    local swap_used = output.memory.swap_usage
    local gpu_used = math.floor(output.gpu_usage[2] * 100)
    local gpu_temp = output.temp.gpu_temp_avg

    if not (ecpu_val and pcpu_val and cpu_temp and ram_total and ram_used
        and swap_total and swap_used and gpu_used and gpu_temp) then
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
      label = math.floor(output.all_power or 0) .. " W",
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
