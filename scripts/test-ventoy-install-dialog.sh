#!/usr/bin/env bash
# Ensure Ventoy's text output and confirmation are handled by dialog safely.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
(
  cd "$ROOT_DIR"
  export ISOFORGE_DISABLE_EXIT_TRAP=1
  source ./inc/isoforge.sh
  DIALOG_WIDTH=72

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  installer="$tmpdir/Ventoy2Disk.sh"
  answer="$tmpdir/answer"
  cat >"$installer" <<EOF
#!/usr/bin/env bash
read -r reply
printf '%s' "\$reply" >"$answer"
printf 'Ventoy text output that belongs in a program box\n'
EOF
  chmod +x "$installer"

  programbox_seen="$tmpdir/programbox-seen"
  gauge_seen="$tmpdir/gauge-seen"
  REPO_ROOT="$tmpdir"
  # shellcheck disable=SC2317 # invoked indirectly by flash_with_ventoy
  dialog_init() { :; }
  dialog() {
    [[ "$*" == *--programbox* ]] && : >"$programbox_seen"
    [[ "$*" == *--gauge* ]] && : >"$gauge_seen"
    if [[ "$*" == *--programbox* ]]; then cat >/dev/null; fi
    return 0
  }
  sudo() {
    [[ "${1:-}" == '-v' ]] && return 0
    "$@"
  }
  ensure_ventoy_available() { VENTOY_BIN="$installer"; }
  flash_confirm() { return 0; }
  ensure_space_or_prune() { return 0; }
  copy_isos_to_ventoy() { return 0; }
  sync() { :; }
  lsblk() {
    if [[ "$*" == *'-ln'* ]]; then
      printf 'sdb1 part 1000000 VENTOY exfat\n'
    fi
  }
  # shellcheck disable=SC2317 # invoked indirectly by flash_with_ventoy
  mount() { return 0; }

  SELECTED_DEVICE=sdb
  SELECTED_IMAGES=("$tmpdir/test.iso")
  : >"${SELECTED_IMAGES[0]}"
  flash_with_ventoy
  [[ "$(cat "$answer")" == y ]]
  [[ -f "$programbox_seen" ]]
  [[ ! -e "$gauge_seen" ]]
)

# Bundled backgrounds are PNG because Ventoy renders raster files reliably.
[[ -f "$ROOT_DIR/assets/isoforge-logo.svg" ]]
[[ -f "$ROOT_DIR/assets/ventoy/isoforge-background.svg" ]]
[[ -f "$ROOT_DIR/assets/ventoy/nikos-background.svg" ]]
[[ -f "$ROOT_DIR/assets/ventoy/isoforge-background.png" ]]
[[ -f "$ROOT_DIR/assets/ventoy/nikos-background.png" ]]
grep -q 'isoforge "IsoForge — dark forge"' "$ROOT_DIR/inc/isoforge.sh"
grep -q 'nikos "NikOS — dark slate"' "$ROOT_DIR/inc/isoforge.sh"
