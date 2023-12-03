#!/usr/bin/env bash
############## LEFT ITEMS ##############

sketchybar -m --add item mail left \
              --set mail associated_space=1,2,3 \
                    update_freq=30 \
                    script="$PLUGIN_DIR/mail.sh" \
                    icon.font="$FONT:Bold:18.0" \
                    icon=

# show current VPN connection name
sketchybar -m --add item vpn left \
              --set vpn icon= update_freq=5 script="$PLUGIN_DIR/vpn.sh"
