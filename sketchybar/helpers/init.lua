-- install if not found
os.execute "[ ! -d $HOME/.local/share/sketchybar_lua/ ] && (git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && cd /tmp/SbarLua/ && make install && rm -rf /tmp/SbarLua/)"

-- Add the sketchybar module to the package cpath
package.cpath = package.cpath
  .. ";/Users/"
  .. os.getenv "USER"
  .. "/.local/share/sketchybar_lua/?.so"

os.execute "(cd /Users/frankroeder/.dotfiles/sketchybar/helpers && make)"
