local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local ui = require "ui"
local popup_row_height = settings.ui.popup_row_height

local brew = sbar.add("item", "widgets.brew", {
  position = "right",
  padding_left = 4,
  padding_right = 4,
  update_freq = 3600,
  -- No padding overrides: inherit the default icon paddings so the capsule
  -- breathes evenly like the other top widgets.
  icon = {
    string = icons.brew,
    color = colors.blue,
    font = { size = 14.0 },
  },
  label = {
    string = "?",
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
  },
  popup = {
    align = "right",
    height = 30,
  },
  background = ui.widget_background(),
})

local cached_packages = {}
local last_count = 0

local function brew_color(count)
  if count >= 10 then
    return colors.red
  elseif count > 0 then
    return colors.yellow
  end
  return colors.subtext1
end

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

    last_count = count
    local color = brew_color(count)

    brew:set {
      label = { string = tostring(count), color = color },
      icon = { color = color },
    }
  end)
end

brew:subscribe({ "routine", "forced", "deferred_wake" }, update_brew)

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
    local no_updates = sbar.add("item", "widgets.brew.empty", {
      position = "popup." .. brew.name,
      label = {
        string = "No outdated packages",
        font = {
          family = settings.font.family,
          style = settings.font.style_map["Regular"],
          size = 12.0,
        },
        padding_left = 10,
        padding_right = 10,
      },
      icon = { drawing = false },
      background = ui.button {},
    })
    table.insert(popup_items, no_updates)
  else
    for idx, package in ipairs(cached_packages) do
      local pkg_item = sbar.add("item", "widgets.brew.pkg." .. idx, {
        position = "popup." .. brew.name,
        label = {
          string = package,
          font = {
            family = settings.font.family,
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
          color = colors.subtext1,
        },
        background = { height = popup_row_height },
      })
      table.insert(popup_items, pkg_item)
    end
  end
end

ui.bind_popup(brew, {
  on_open = populate_popup,
  on_right = function()
    brew:set { label = { string = "..." } }
    update_brew()
  end,
})

brew:subscribe("theme_colors_updated", function()
  local color = brew_color(last_count)
  brew:set {
    background = ui.widget_background(),
    icon = { color = color },
    label = { color = color },
  }
end)

update_brew()
