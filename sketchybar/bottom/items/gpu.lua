local icons = require('icons')
local colors = require('colors')

local gpu = sbar.add('graph', 'widgets.gpu', 80, {
  position = "right",
  graph = { color = colors.blue },
  icon = {
		string = icons.gpu,
		color = colors.teal,
    padding_left = 4,
    y_offset = 2,
	},
  label = {
    string = 'GPU ??% ??°C',
    font = {
      size = 10.0,
    },
    align = "right",
    width = 0,
    padding_right = 8,
    y_offset = 8,
	},
  update_freq = 2,
})

gpu:subscribe('routine', function(env)
  sbar.exec('macmon pipe -s 1 | jq -r \'[(.gpu_usage[1] * 100 | floor), .temp.gpu_temp_avg] | join(",")\'' , function(output)
    local parts = {}
    for part in string.gmatch(output, '([^,]+)') do
      table.insert(parts, part)
    end
    local load = tonumber(parts[1])
    local temp = tonumber(parts[2])
    if load and temp then
      gpu:push({ load / 100. })

      local color = colors.blue
      if load > 30 then
        if load < 60 then
          color = colors.yellow
        elseif load < 80 then
          color = colors.orange
        else
          color = colors.red
        end
      end

      gpu:set({
        graph = { color = color },
        label = "GPU " .. load .. '% ' .. math.floor(temp) .. '°C',
      })
    end
  end)
end)
