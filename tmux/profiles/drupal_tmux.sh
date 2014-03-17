#!/bin/bash
SESSION_NAME=${PWD##*/}
cd git/
tmux has-session -t "$SESSION_NAME" 2> /dev/null
if [ $? != 0  ]; then
  # new session and window 1: shell on drupal
  # -d detaches, -n is for name
  # don't specify the command to execute here even if it's possible because we
  # want the window (and its shell) to remain open even after the command (e.g.
  # vim) exits, and remain-on-exit option does not help much either.
  tmux new-session -s "$SESSION_NAME" -d -n "drupal"

  # window: vim drupal
  tmux new-window -n 'vim drupal' -t "$SESSION_NAME"
  # sending C-m here is not very useful because our bash prompt is slooow and
  # needs a sleep call before accepting user input
  tmux send-keys -t "$SESSION_NAME":2 "vim"

  # window: tail php
  # don't specify the command for new-windows, see above why.
  tmux new-window -n logphp -t "$SESSION_NAME"
  tmux send-keys -t "$SESSION_NAME":3  "tlphp"

  # window: mysql drupal
  tmux new-window -n mysql-drupal -t "$SESSION_NAME"
  tmux send-keys -t "$SESSION_NAME":4 'dsq'

  tmux select-window -t "$SESSION_NAME":1
  sleep 1
  tmux send-keys -t "$SESSION_NAME":2 C-m
  tmux send-keys -t "$SESSION_NAME":3 C-m
fi
tmux attach -t "$SESSION_NAME"
