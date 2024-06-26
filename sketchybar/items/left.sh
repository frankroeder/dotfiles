#!/usr/bin/env bash
############## LEFT ITEMS ##############

sketchybar --add event aerospace_workspace_change
for sid in $(aerospace list-workspaces --all); do
    sketchybar --add item space.$sid left \
        --subscribe space.$sid aerospace_workspace_change \
        --set space.$sid \
        background.color=0x44ffffff \
        background.corner_radius=5 \
        background.height=20 \
        background.drawing=off \
        label="$sid" \
        click_script="aerospace workspace $sid" \
        script="$CONFIG_DIR/plugins/aerospace.sh $sid"
done

sketchybar -m --add item mail left \
              --set mail associated_space=1,2,3 \
                    update_freq=30 \
                    script="$PLUGIN_DIR/mail.sh" \
                    icon.font="$FONT:Bold:18.0" \
                    icon=
# show current VPN connection name
sketchybar -m --add item vpn left \
              --set vpn icon= update_freq=5 script="$PLUGIN_DIR/vpn.sh"
