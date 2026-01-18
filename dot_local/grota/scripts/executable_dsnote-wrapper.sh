#!/usr/bin/env bash

print_help() {
  cat <<EOF
Usage: $(basename "$0") [COMMAND]

Commands:
  print_current_model      Print the currently active STT model
  switch_next_stt          Switch to the next available STT model
  toggle_listening         Toggle listening mode for active window
  toggle_translating       Toggle translating mode for active window
  choose_model             Interactively choose an STT model from available models
  -h, --help               Show this help message

If no command is specified, 'print_current_model' is used by default.
EOF
}

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

choose_model() {
  local models model_count selection model_id
 
  mapfile -t models < <(dsnote --print-available-models stt 2> /dev/null | tail -n +2)
  model_count=${#models[@]}

  if [[ $model_count -eq 0 ]]; then
    echo "No STT models available" 1>&2
    return 1
  fi

  echo "Available STT models:"
  for i in "${!models[@]}"; do
    printf "%2d) %s\n" $((i + 1)) "${models[$i]}"
  done

  echo
  read -rp "Choose a model (1-$model_count): " selection

  if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "$model_count" ]]; then
    echo "Invalid selection" 1>&2
    return 1
  fi

  model_id=$(echo "${models[$((selection - 1))]}" | awk '{print $1}')

  echo "Setting model to: $model_id"
  dsnote --action set-stt-model --id "$model_id" 2> /dev/null

  print_current_model
}

if [[ $# -eq 0 ]]; then
  print_help
  echo
  cmd="print_current_model"
else
  cmd="$1"
  shift
  
  if [[ "$cmd" == "-h" || "$cmd" == "--help" ]]; then
    print_help
    exit 0
  fi
fi

public_commands=(
  "print_current_model"
  "switch_next_stt"
  "toggle_listening"
  "toggle_translating"
  "choose_model"
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
