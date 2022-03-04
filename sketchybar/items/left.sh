#!/usr/bin/env bash
############## LEFT ITEMS ##############

# yabai space number
sketchybar -m --add item yabai_spaces left                                            \
              --set yabai_spaces drawing=off                                          \
                                 updates=on                                           \
                                 script="$PLUGIN_DIR/yabai_spaces.sh"                 \
              --subscribe yabai_spaces space_change window_created window_destroyed   \
                                                                                      \
              --add item space_template left                                          \
              --set      space_template icon.highlight_color=0xff9dd274               \
                                 label.font="$FONT:Bold:14"                           \
                                 drawing=off                                          \
                                 lazy=off

sketchybar -m --add item yabai_layout left                                            \
              --set yabai_layout script="$PLUGIN_DIR/yabai_layout.sh"                 \
                    lazy=off                                                          \
              --subscribe yabai_layout front_app_switched window_focus layout_change  \
                                                                                      \
              --add item yabai_property left                                          \
              --set yabai_property script="$PLUGIN_DIR/yabai_property.sh"             \
                    label.font="$FONT:Bold:12"                                        \
                    lazy=off                                                          \
              --subscribe yabai_property front_app_switched window_focus property_change

sketchybar -m --add item space_separator left                                         \
              --set space_separator  icon="|"                                         \
                                     icon.padding_left=15                             \
                                     label.padding_right=15                           \
                                     icon.font="$FONT:Bold:15.0"                      \
              --add item mail left                                                    \
              --set mail associated_space=1,2,3                                       \
                      update_freq=30                                                  \
                      script="$PLUGIN_DIR/mail.sh"                                    \
                      icon.font="$FONT:Bold:18.0"                                     \
                      icon=

# show current VPN connection name
sketchybar -m --add item vpn left \
              --set vpn icon= update_freq=5 script="$PLUGIN_DIR/vpn.sh"
