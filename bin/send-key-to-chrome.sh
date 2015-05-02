#!/bin/sh
PREV_WINDOW_ID=`xdotool getwindowfocus`
# Not sure why but we have to use ctrl here.
KEY=ctrl+${1:-XF86AudioPlay}
# Then any of the many chrome extensions inside chrome will suffice to get the job done.
xdotool search  -classname '/home/grota/.config/google-chrome-beta' windowactivate key $KEY
xdotool windowactivate $PREV_WINDOW_ID
