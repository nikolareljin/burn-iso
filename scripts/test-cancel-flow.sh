#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

(
  cd "$ROOT_DIR"
  set -- --unexpected-flag
  export ISOFORGE_DISABLE_EXIT_TRAP=1
  source ./inc/isoforge.sh
  [[ "$#" -eq 1 && "$1" == "--unexpected-flag" ]]

  SELECTED_IMAGE="/stable.iso"
  SELECTED_DEVICE="sda"
  SELECTED_BACKGROUND="/stable.png"
  SELECTED_IMAGES=("/stable.iso")

  cancelled_action() {
    SELECTED_IMAGE="/partial.iso"
    SELECTED_DEVICE="sdb"
    SELECTED_BACKGROUND="/partial.png"
    SELECTED_IMAGES=("/partial-a.iso" "/partial-b.iso")
    return 7
  }

  set +e
  run_main_menu_action cancelled_action
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    echo "expected cancelled_action to fail" >&2
    exit 1
  fi
  [[ "$status" -eq 7 ]]
  [[ "$SELECTED_IMAGE" == "/stable.iso" ]]
  [[ "$SELECTED_DEVICE" == "sda" ]]
  [[ "$SELECTED_BACKGROUND" == "/stable.png" ]]
  [[ "${#SELECTED_IMAGES[@]}" -eq 1 && "${SELECTED_IMAGES[0]}" == "/stable.iso" ]]

  successful_action() {
    SELECTED_IMAGE="/next.iso"
    SELECTED_DEVICE="sdc"
    SELECTED_BACKGROUND="/next.png"
    SELECTED_IMAGES=("/next.iso" "/next-extra.iso")
    return 0
  }

  run_main_menu_action successful_action
  [[ "$SELECTED_IMAGE" == "/next.iso" ]]
  [[ "$SELECTED_DEVICE" == "sdc" ]]
  [[ "$SELECTED_BACKGROUND" == "/next.png" ]]
  [[ "${#SELECTED_IMAGES[@]}" -eq 2 ]]
)

tmp_output="$(mktemp)"
set +e
ISOFORGE_DISABLE_EXIT_TRAP=1 bash ./inc/isoforge.sh --config >"$tmp_output" 2>&1
status=$?
set -e
if [[ "$status" -eq 0 ]]; then
  echo "expected parse_cli_args --config to fail" >&2
  rm -f "$tmp_output"
  exit 1
fi
output="$(cat "$tmp_output")"
rm -f "$tmp_output"
[[ "$status" -eq 2 ]]
[[ "$output" == *"Missing value for --config"* ]]
