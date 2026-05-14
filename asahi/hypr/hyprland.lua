-- Hyprland 0.55+ Lua config for Asahi Fedora.

configDir = os.getenv("HOME") .. "/.config/hypr"
dotfilesDir = os.getenv("HOME") .. "/.dotfiles"

terminal = "ghostty"
browser = "librewolf"
launcher = "walker"
mainMod = "SUPER"

local function load_config(name)
  dofile(configDir .. "/conf.d/" .. name .. ".lua")
end

load_config("env")
load_config("monitors")
load_config("input")
load_config("asahi")
load_config("general")
load_config("animations")
load_config("rules")
load_config("bindings")
load_config("autostart")
