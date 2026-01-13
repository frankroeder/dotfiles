local icons = require('icons')
local colors = require('colors')


local gpu = sbar.add('graph', 'widgets.gpu', 80, {
  position = "right",
  graph = { color = colors.blue },
  icon = {
  		string = icons.gpu,
  		color = colors.teal,
     padding_left = 4,
     y_offset = 0,
 	},
  label = {
    string = 'GPU ??% ??°C',
    font = {
      size = 10.0,
    },
    align = "right",
    width = 0,
    padding_right = 6,
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
    string = "RAM ??% SWAP ??%",
    font = {
      size = 10.0,
    },
    align = "right",
    width = 0,
    padding_right = 6,
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
    string = "eCPU ??% pCPU ??% ??°C",
    font = {
      size = 10.0,
    },
    align = "right",
    width = 0,
    padding_right = 6,
    y_offset = 8,
  },
  background = {
    drawing = true,
  },
  update_freq = 2,
})

local ecpu = sbar.add("graph", "widgets.ecpu", 138, {
  position = "right",
  graph = { color = colors.green },
  background = { drawing = false },
  icon = { drawing = false },
  label = { drawing = false },
  padding_right = -163,
  y_offset = 4,
})

local ram_popup = sbar.add("item", {
  position = "popup." .. ram_g.name,
  label = {
    font = { size = 12.0 },
    string = "Checking memory pressure...",
  },
})

local power = sbar.add('item', 'widgets.power', {
  position = "right",
  icon = {
    string = icons.power,
    color = colors.yellow,
    padding_left = 2,
    padding_right = -1,
  },
  label = {
    string = '?? W',
    font = {
      size = 10.0,
    },
    padding_right = 3,
  },
  padding_right = 23,
})

cpu:subscribe('routine', function(env)
  sbar.exec('/opt/homebrew/bin/macmon pipe -s 1', function(output)
    if not output or not output.ecpu_usage or not output.pcpu_usage or not output.temp or not output.memory or not output.gpu_usage then return end
    local ecpu_val = math.floor(output.ecpu_usage[2] * 100)
    local pcpu_val = math.floor(output.pcpu_usage[2] * 100)
    local cpu_temp = output.temp.cpu_temp_avg
    local ram_total = output.memory.ram_total
    local ram_used = output.memory.ram_usage
    local swap_total = output.memory.swap_total
    local swap_used = output.memory.swap_usage
    local gpu_used = math.floor(output.gpu_usage[2] * 100)
    local gpu_temp = output.temp.gpu_temp_avg

    if ecpu_val and pcpu_val and cpu_temp and ram_total and ram_used and swap_total and swap_used and gpu_used and gpu_temp then

      -- Update CPU
      cpu:set({
        graph = { color = colors.blue },
        label = "eCPU " .. ecpu_val .. "% pCPU " .. pcpu_val .. "% " .. math.floor(cpu_temp) .. "°C",
      })
      cpu:push({ pcpu_val / 100. })
      ecpu:push({ ecpu_val / 100. })

      -- Update RAM
      local ram_pct = (ram_used / ram_total) * 100
      local swap_pct = (swap_used / swap_total) * 100
      local color_ram = colors.blue
      if ram_pct > 30 then
        if ram_pct < 60 then
          color_ram = colors.yellow
        elseif ram_pct < 80 then
          color_ram = colors.orange
        else
          color_ram = colors.red
        end
      end
      ram_g:set({
        graph = { color = color_ram },
        label = "RAM " .. math.floor(ram_pct) .. "% SWAP " .. math.floor(swap_pct) .. "%",
      })
      ram_g:push({ ram_pct / 100. })

      -- Update GPU
      local color_gpu = colors.blue
      if gpu_used > 30 then
        if gpu_used < 60 then
          color_gpu = colors.yellow
        elseif gpu_used < 80 then
          color_gpu = colors.orange
        else
          color_gpu = colors.red
        end
      end
      gpu:set({
        graph = { color = color_gpu },
        label = "GPU " .. gpu_used .. '% ' .. math.floor(gpu_temp) .. '°C',
      })
      gpu:push({ gpu_used / 100. })

      -- Update Power
      local power_val = output.all_power
      power:set({
        label = math.floor(power_val) .. " W",
      })
    end
  end)
end)

cpu:subscribe("mouse.clicked", function(_)
  sbar.exec "open -a 'Activity Monitor'"
end)

ram_g:subscribe("mouse.clicked", function()
  ram_g:set { popup = { drawing = "toggle" } }
  sbar.exec("memory_pressure | tail -n 3", function(pressure)
    ram_popup:set { label = { string = pressure } }
  end)
end)

ram_g:subscribe("mouse.exited.global", function()
  ram_g:set { popup = { drawing = false } }
end)