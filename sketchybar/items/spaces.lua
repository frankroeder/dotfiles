-- spaces.lua
local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"

sbar.exec("aerospace list-workspaces --all", function(space_names)
  for space_name in space_names:gmatch "[^\r\n]+" do
    local space = sbar.add("item", "workspace_" .. space_name, {
      icon = {
        color = colors.white,
        highlight_color = colors.blue,
        font = { family = settings.font.numbers },
        drawing = false,
        string = space_name,
        padding_left = 10,
        padding_right = 5,
      },
      label = {
        font = "sketchybar-app-font:Regular:16.0",
        string = "",
        color = colors.grey,
        highlight_color = colors.blue,
        drawing = false,
        padding_right = 12,
        y_offset = -1,
      },
      background = {
        color = colors.bg1,
        border_width = 1,
        height = 24,
        border_color = colors.black,
      },
      padding_left = settings.paddings,
      padding_right = settings.paddings,
      click_script = "aerospace workspace " .. space_name,
    })

    -- Add bracket for double border on highlight
    local space_bracket = sbar.add("bracket", { space.name }, {
      background = {
        color = colors.transparent,
        border_color = colors.transparent,
        height = 26,
        border_width = 1,
        corner_radius = 9,
        drawing = true,
      },
    })

    space:subscribe("aerospace_workspace_change", function(env)
      local selected = env.FOCUSED_WORKSPACE == space_name
      local color = selected and colors.orange or colors.bg2

      -- When selected, highlight icon & label
      space:set {
        icon = { highlight = selected },
        label = { highlight = selected },
      }
      space_bracket:set {
        background = { border_color = color },
      }

      if selected then
        -- Query the apps in the workspace:
        sbar.exec(
          "aerospace list-windows --format %{app-name} --workspace " .. space_name,
          function(windows)
            local icon_line = ""
            local has_app = false
            for app in windows:gmatch "[^\r\n]+" do
              has_app = true
              local lookup = app_icons[app] or app_icons["default"]
              icon_line = icon_line .. " " .. lookup
            end

            sbar.animate("tanh", 10, function()
              if has_app then
                -- Show icons and the label
                space:set {
                  icon = {
                    drawing = true,
                    string = space_name,
                  },
                  label = {
                    drawing = true,
                    string = icon_line, -- puts the icons in the 'icon' property
                  },
                  background = {
                    drawing = true,
                  },
                  padding_right = settings.paddings,
                  padding_left = settings.paddings,
                }
              else
                -- If no apps, hide icon & restore label to just the space name
                space:set {
                  icon = {
                    drawing = true,
                    string = space_name,
                  },
                  label = {
                    drawing = false,
                    string = "",
                  },
                  background = {
                    drawing = true,
                  },
                  padding_right = settings.paddings,
                  padding_left = settings.paddings,
                }
              end
            end)
          end
        )
      else
        -- If not selected, hide icons & revert to original label
        space:set {
          icon = {
            drawing = true,
            string = space_name,
          },
          label = {
            drawing = false,
            string = "",
          },
          background = {
            drawing = true,
          },
          padding_right = settings.paddings,
          padding_left = settings.paddings,
        }
      end
    end) -- end subscribe
  end
end)
