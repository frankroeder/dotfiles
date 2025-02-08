local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"

sbar.add("event", "flashspace_workspace_change")

local function parse_string_to_table(s)
  local result = {}
  for line in s:gmatch "([^\n]+)" do
    table.insert(result, line)
  end
  return result
end

local file =
  io.popen [[jq -r --arg id "$(jq -r ".selectedProfileId" ~/.config/flashspace/profiles.json)" 'first(.profiles[] | select(.id == $id)) | .workspaces[].name' ~/.config/flashspace/profiles.json]]
local workspaces = file:read "*a"
file:close()

print("Workspaces", workspaces)

for _, space_name in ipairs(parse_string_to_table(workspaces)) do
  local space = sbar.add("item", "workspace_" .. space_name, {
    icon = {
      color = colors.white,
      highlight_color = colors.blue,
      string = space_name,
      padding_left = 8,
      padding_right = 4,
    },
    label = {
      font = "sketchybar-app-font:Regular:16.0",
      string = "",
      color = colors.grey,
      highlight_color = colors.blue,
      y_offset = -1,
    },
    background = {
      color = colors.bg2,
      border_width = 1,
      height = 24,
      border_color = colors.black,
    },
    padding_right = -4,
    -- click_script = "aerospace workspace " .. space_name,
  })

  space:subscribe("flashspace_workspace_change", function(env)
    local selected = env.WORKSPACE == space_name
    -- print("SELECTED", env.NAME, selected, space_name, env.WORKSPACE)
    space:set {
      icon = { highlight = selected },
      label = { highlight = selected },
      background = { border_color = selected and colors.orange or colors.bg2 },
    }
    -- if selected then
    --   -- sbar.exec(
    --   --   "aerospace list-windows --format %{app-name} --workspace " .. space_name,
    --   --   function(windows)
    --   local icon_line = ""
    --   local has_app = false
    --   for app in windows:gmatch "[^\r\n]+" do
    --     has_app = true
    --     local lookup = app_icons[app] or app_icons["Default"]
    --     icon_line = icon_line .. " " .. lookup
    --   end

    --   sbar.animate("tanh", settings.animation_duration, function()
    --     if has_app then
    --       space:set {
    --         label = {
    --           string = icon_line,
    --           padding_right = 8,
    --         },
    --       }
    --     else
    --       space:set {
    --         label = {
    --           string = "",
    --           padding_right = 2,
    --         },
    --       }
    --     end
    --   end)
    --     -- end
    --   -- )
    -- else
    --   space:set {
    --     label = {
    --       string = "",
    --       padding_right = 2,
    --     },
    --   }
    -- end
  end)
end

-- sketchybar --add event flashspace_workspace_change

-- SID=1
-- SELECTED_PROFILE_ID=$(jq -r ".selectedProfileId" ~/.config/flashspace/profiles.json)
-- WORKSPACES=$(jq -r --arg id "$SELECTED_PROFILE_ID" 'first(.profiles[] | select(.id == $id)) | .workspaces[].name' ~/.config/flashspace/profiles.json)

-- for workspace in $WORKSPACES; do
--   sketchybar --add item flashspace.$SID left \
--     --subscribe flashspace.$SID flashspace_workspace_change \
--     --set flashspace.$SID \
--     background.color=0x22ffffff \
--     background.corner_radius=5 \
--     background.padding_left=5 \
--     label.padding_left=5 \
--     label.padding_right=5 \
--     label="$workspace" \
--     script="$CONFIG_DIR/plugins/flashspace.sh $workspace"

--   SID=$((SID + 1))
-- done

-- for _, space_name in ipairs(parse_string_to_table(result)) do
--   local space = sbar.add("item", "workspace_" .. space_name, {
--     icon = {
--       color = colors.white,
--       highlight_color = colors.blue,
--       string = space_name,
--       padding_left = 8,
--       padding_right = 4,
--     },
--     label = {
--       font = "sketchybar-app-font:Regular:16.0",
--       string = "",
--       color = colors.grey,
--       highlight_color = colors.blue,
--       y_offset = -1,
--     },
--     background = {
--       color = colors.bg2,
--       border_width = 1,
--       height = 24,
--       border_color = colors.black,
--     },
--     padding_right = -4,
--     click_script = "aerospace workspace " .. space_name,
--   })

--   space:subscribe("aerospace_workspace_change", function(env)
--     local selected = env.FOCUSED_WORKSPACE == space_name
--     space:set {
--       icon = { highlight = selected },
--       label = { highlight = selected },
--       background = { border_color = selected and colors.orange or colors.bg2 },
--     }
--     if selected then
--       sbar.exec(
--         "aerospace list-windows --format %{app-name} --workspace " .. space_name,
--         function(windows)
--           local icon_line = ""
--           local has_app = false
--           for app in windows:gmatch "[^\r\n]+" do
--             has_app = true
--             local lookup = app_icons[app] or app_icons["Default"]
--             icon_line = icon_line .. " " .. lookup
--           end

--           sbar.animate("tanh", settings.animation_duration, function()
--             if has_app then
--               space:set {
--                 label = {
--                   string = icon_line,
--                   padding_right = 8,
--                 },
--               }
--             else
--               space:set {
--                 label = {
--                   string = "",
--                   padding_right = 2,
--                 },
--               }
--             end
--           end)
--         end
--       )
--     else
--       space:set {
--         label = {
--           string = "",
--           padding_right = 2,
--         },
--       }
--     end
--   end)
-- end
