local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local mail = sbar.add("item", "widgets.mail", 42, {
	position = "center",
	background = {
		height = 22,
		color = { alpha = 0 },
		border_width = 0,
		drawing = true,
	},
	icon = {
		string = ":mail:",
		color = colors.green,
		font = "sketchybar-app-font:Regular:18.0",
	},
	label = {
		string = "0",
		font = {
			family = settings.font.numbers,
			style = settings.font.style_map["Bold"],
		},
		align = "right",
		padding_right = 0,
	},
	update_freq = 5,
	padding_right = settings.paddings,
})

local function update_mail_count()
	sbar.exec(
		[[
        osascript -e 'tell application "Mail" to count of (messages of inbox whose read status is false)'
    ]],
		function(count)
			local mail_count = tonumber(count) or 0
			mail:set({
				label = {
					string = tostring(mail_count),
				},
				icon = {
					color = colors.green,
				},
			})
		end
	)
end

mail:subscribe("mouse.clicked", function(_)
    sbar.exec("open -a Mail")
end)

sbar.add("event", "mail_check")

mail:subscribe("mail_check", "routine", "system_woke", function(_)
	update_mail_count()
end)

update_mail_count()
