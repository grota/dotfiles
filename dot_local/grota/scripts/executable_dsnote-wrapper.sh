#!/usr/bin/env bash

print_current_model() {
  local DSNOTE_OUT_ACTIVE_MODEL SUMMARY
  DSNOTE_OUT_ACTIVE_MODEL=$(dsnote --print-active-model stt 2> /dev/null | tail -n1)
  SUMMARY="$(echo -n "$DSNOTE_OUT_ACTIVE_MODEL" | cut -d' ' -f2-)"
  notify-send "$SUMMARY"
  echo "$SUMMARY"
}

switch_next_stt() {
  dsnote --action switch-to-next-stt-model 2> /dev/null
  print_current_model
}

# Assumes option "toggle behavior for actions" is set in dsnote
toggle_listening() {
  print_current_model
  dsnote --action start-listening-active-window 2> /dev/null
}

toggle_translating() {
  print_current_model
  dsnote --action start-listening-translate-active-window 2> /dev/null
}

cmd="${1:-print_current_model}"
shift

public_commands=(
  "print_current_model"
  "switch_next_stt"
  "toggle_listening"
)

# shellcheck disable=SC2076
if [[ ! " ${public_commands[*]} " =~ " ${cmd} " ]] ; then
  echo Invalid command "$cmd" 1>&2
  exit 1
fi

# Check if dsnote is already running
if ! pgrep -x "dsnote" > /dev/null; then
  nohup dsnote --start-in-tray 2> /dev/null > /dev/null & disown
  export DSNOTE_WRAPPER_STARTED=1
  sleep 1
fi

"${cmd}" "$@"
