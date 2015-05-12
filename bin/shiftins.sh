#!/bin/sh
DELAY=0
SELECTION="$(xsel)"
# If outside of ascii plane use a higher delay
if echo $SELECTION | grep -q -P '[^\x00-\x7F]'; then
  DELAY=60
else
  DELAY=4
fi
echo $DELAY
# Keyup Shift_L is to cope with a strange behavior with ergodox's macro.
# sleep 0.2 is required for the laptop keyboard
sleep 0.2 && xdotool keyup Shift_L type --delay $DELAY "${SELECTION}"
