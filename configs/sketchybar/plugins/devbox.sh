#!/bin/sh

# Polls remote devbox state via checkdevbox.sh and updates the sketchybar item.
OUT="$("$HOME/.config/nvim/configs/script/checkdevbox.sh" 2>/dev/null)"

case "$OUT" in
  *UP*)
    ICON=""
    LABEL="devbox up"
    COLOR=0xff00ff00
    ;;
  *PROVISIONING*)
    ICON=""
    LABEL="devbox provisioning"
    COLOR=0xffffcc00
    ;;
  *)
    ICON=""
    LABEL="devbox down"
    COLOR=0xffff0000
    ;;
esac

sketchybar --set "$NAME" icon="$ICON" label="$LABEL" icon.color="$COLOR" label.color="$COLOR"
