#!/usr/bin/env bash
############## RIGHT ITEMS ##############

# cpu graphs
sketchybar -m --add graph cpu_user right 200                                  \
              --set cpu_user     graph.color=0xffffffff                       \
                                 update_freq=2                                \
                                 width=0                                      \
                                 associated_space=1,2,3                       \
                                 icon.font="$FONT:Bold:11"                    \
                                 icon=CPU                                     \
                                 script="$PLUGIN_DIR/cpu_graph.sh"            \
                                 lazy=on                                      \
                                                                              \
              --add graph cpu_sys right 200                                   \
              --set cpu_sys associated_space=1,2,3                            \
                                  graph.color=0xff48aa2a                      \
                                                                              \
              --add item topmem right                                         \
              --set topmem      associated_space=1,2,3                        \
                                icon.padding_left=5                           \
                                update_freq=15                                \
                                script="$PLUGIN_DIR/topmem.sh"                \
                                                                              \
              --add item topproc right                                        \
              --set topproc      associated_space=1,2,3                       \
                                 label.padding_left=5                         \
                                 update_freq=15                               \
                                 script="$PLUGIN_DIR/topproc.sh"

# network stats
sketchybar -m --add item network_up right                                     \
            --set network_up label.font="$FONT:Bold:9"                        \
                                  icon.font="$FONT:Bold:12"                   \
                                  icon=↑                                      \
                                  icon.highlight_color=0xff8b0a0d             \
                                  y_offset=5                                  \
                                  width=0                                     \
                                  update_freq=2                               \
                                  script="$PLUGIN_DIR/network.sh"             \
                                                                              \
              --add       item    network_down right                          \
              --set       network_down label.font="$FONT:Bold:9"              \
                                      icon.font="$FONT:Bold:12"               \
                                      icon=↓                                  \
                                      icon.highlight_color=0xff10528c         \
                                      y_offset=-5

