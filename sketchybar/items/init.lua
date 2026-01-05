require "items.media"
require "items.mails"
require "items.downloads"
require "items.github"
require "items.mode"
require "items.reminders"
require "items.pomodoro"
require "items.coffee"
require "items.zen"
require "items.brew"
require "items.trash"
require "items.ssh"
require "items.hackernews"
require "items.arxiv"

require "items.ssd"
sbar.add("bracket", "widgets.ticker", {
  "widgets.hackernews",
  "widgets.arxiv"
}, {
  background = {
    color = 0xff1e1e2e,
    border_color = 0xff313244,
    border_width = 1,
    height = 24,
    corner_radius = 11,
  }
})

sbar.add("bracket", "widgets.controls", {
  "widgets.mode",
  "widgets.reminders",
  "widgets.github",
  "widgets.pomodoro",
  "widgets.pomodoro.start",
  "widgets.coffee",
  "widgets.zen",
  "widgets.brew",
  "widgets.trash",
  "widgets.downloads",
  "widgets.python",
  "widgets.ssh"
}, {
  background = {
    color = 0xff1e1e2e,
    border_color = 0xff313244,
    border_width = 1,
    height = 24,
    corner_radius = 11,
  }
})

sbar.add("bracket", "widgets.sys", {
  "widgets.cpu",
  "widgets.ram",
  "widgets.ssd.volume",
  "widgets.ip",
  "widgets.network_down",
  "widgets.network_up",
  "widgets.swap"
}, {
  background = {
    color = 0xff1e1e2e,
    border_color = 0xff313244,
    border_width = 1,
    height = 24,
    corner_radius = 11,
  }
})