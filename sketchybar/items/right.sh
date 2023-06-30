#!/usr/bin/env bash
############## RIGHT ITEMS ##############

sketchybar -m --add item topproc right \
              --set topproc update_freq=5 \
                    icon.drawing=off \
                    width=0 \
                    y_offset=6 \
                    label.font="$FONT:Bold:10.0" \
                    script="$PLUGIN_DIR/topproc.sh" \
                    lazy=on \
              \
              --add item cpu_percent right \
              --set cpu_percent label.font="$FONT:Bold:12" \
                    y_offset=-4 \
                    width=40 \
                    icon.drawing=off \
                    update_freq=2 \
                    lazy=on \
              \
              --add graph cpu_user right 150 \
              --set cpu_user graph.color=0xffe1e3e4 \
                    update_freq=2 \
                    width=0 \
                    script="$PLUGIN_DIR/cpu_graph.sh" \
                    label.drawing=off \
                    icon.drawing=off \
                    background.height=23 \
                    background.color=0x00000000 \
                    lazy=on \
              \
              --add graph cpu_sys right 150 \
              --set cpu_sys graph.color=0xff9dd274 \
                    label.drawing=off \
                    icon.drawing=off \
                    background.height=23 \
                    background.color=0x00000000 \
                    background.border_color=0x00000000 \
              --add bracket cpu \
                    cpu_separator \
                    cpu_topproc \
                    cpu_percent \
                    cpu_user \
                    cpu_sys \
              --set cpu background.drawing=on

# network stats
sketchybar -m --add item topmem right \
              --set topmem update_freq=5 \
                    script="$PLUGIN_DIR/topmem.sh" \
                    label.font="$FONT:Bold:12.0" \
                    lazy=on \
              \
              --add item network_up right \
              --set network_up label.font="$FONT:Bold:9" \
                    icon.font="$FONT:Bold:12" \
                    icon=↑ \
                    icon.highlight_color=0xff8b0a0d \
                    y_offset=5 \
                    width=0 \
                    update_freq=2 \
                    script="$PLUGIN_DIR/network.sh" \
              \
              --add item network_down right \
              --set network_down label.font="$FONT:Bold:9" \
                    icon.font="$FONT:Bold:12" \
                    icon=↓ \
                    icon.highlight_color=0xff10528c \
                    y_offset=-5
