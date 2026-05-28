#!/usr/bin/env bash
# Highlight the focused AeroSpace workspace chip.
# Invoked with the workspace id as $1; FOCUSED_WORKSPACE arrives via the trigger.

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "$NAME" background.drawing=on \
                          background.color=0xffffffff \
                          label.color=0xff000000
else
  sketchybar --set "$NAME" background.drawing=off \
                          label.color=0xffffffff
fi
