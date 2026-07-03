-- display_change is triggered by yabai on hotplug and by skhd on space moves.
-- Retargeting while expanded is handled in island_core (window_focus + display_change).
sbar.add("event", "display_change")
sbar.add("event", "window_focus")