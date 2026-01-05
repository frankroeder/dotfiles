require "items.media"

require "items.cpu"
require "items.ram"
require "items.swap"
require "items.ssd"

require "items.mails"
require "items.keyboard"
require "items.messages"
require "items.pomodoro"

local colors = require "colors"

sbar.add("bracket", "bottom.group.hw", {
  "widgets.ssd.volume",
  "widgets.cpu",
  "widgets.ram",
  "widgets.swap"
}, {
  background = {
    drawing = false,
  }
})

sbar.add("bracket", "bottom.group.utils", {
  "widgets.mail",
  "widgets.timer",
  "widgets.keyboard",
  "widgets.messages"
}, {
  background = {
    drawing = false,
  }
})
