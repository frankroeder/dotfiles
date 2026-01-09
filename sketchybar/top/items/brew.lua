local icons = require "icons"
local colors = require "colors"
local settings = require "settings"

local brew = sbar.add("item", "widgets.brew", {
  position = "right",
  update_freq = 3600,
  icon = {
    string = icons.brew,
    color = colors.blue,
    padding_right = 4,
    font = {
      size = 14.0,
    },
  },
  label = {
    string = "?",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    padding_right = 8,
  },
  popup = {
    align = "right",
    height = 30,
  },
})

-- Cache for outdated packages
local cached_packages = {}

local function is_package_line(line)
  if not line or line == "" or line:match "^%s*$" then
    return false
  end
  if
    line:match "^Error:"
    or line:match "^Please report"
    or line:match "^/opt/homebrew"
    or line:match "Troubleshooting"
    or line:match "undefined method"
    or line:match "%.rb:"
  then
    return false
  end
  return true
end

local function update_brew()
  local brew_cmd = '/bin/zsh -c "HOMEBREW_NO_AUTO_UPDATE=1 brew outdated -q"'

  sbar.exec(brew_cmd, function(outdated_output)
    cached_packages = {}
    local count = 0

    if outdated_output then
      for line in outdated_output:gmatch "[^\r\n]+" do
        if is_package_line(line) then
          count = count + 1
          table.insert(cached_packages, line)
        end
      end
    end

    local color = colors.white
    if count >= 10 then
      color = colors.red
    elseif count > 0 then
      color = colors.yellow
    else
      color = colors.white
    end

    brew:set {
      label = {
        string = tostring(count),
        color = color,
      },
      icon = { color = color },
    }
  end)
end

brew:subscribe({ "routine", "forced", "system_woke" }, update_brew)

local popup_items = {}

local function clear_popup()
  for _, item in ipairs(popup_items) do
    sbar.remove(item.name)
  end
  popup_items = {}
end

local function populate_popup()
  clear_popup()

  if #cached_packages == 0 then
    local no_updates = sbar.add("item", {
      position = "popup." .. brew.name,
      label = {
        string = "No outdated packages",
        font = {
          family = settings.font.text,
          style = settings.font.style_map["Regular"],
          size = 12.0,
        },
        padding_left = 10,
        padding_right = 10,
      },
      icon = { drawing = false },
    })
    table.insert(popup_items, no_updates)
  else
    for _, package in ipairs(cached_packages) do
      local pkg_item = sbar.add("item", {
        position = "popup." .. brew.name,
        label = {
          string = package,
          font = {
            family = settings.font.text,
            style = settings.font.style_map["Regular"],
            size = 12.0,
          },
          padding_left = 10,
          padding_right = 10,
        },
        icon = {
          string = "•",
          padding_left = 10,
          padding_right = 4,
          color = colors.white,
        },
        background = {
          height = 20,
        },
      })
      table.insert(popup_items, pkg_item)
    end
  end
end

brew:subscribe("mouse.clicked", function(env)
  local query = brew:query()
  local should_draw = query and query.popup and query.popup.drawing == "off" or true

  if should_draw then
    populate_popup()
  end

  brew:set { popup = { drawing = "toggle" } }
end)

brew:subscribe("mouse.exited.global", function()
  brew:set { popup = { drawing = false } }
end)

update_brew()