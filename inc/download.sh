#!/usr/bin/env bash
set -euo pipefail

# Load shared helpers from submodule in ./scripts (override with SCRIPT_HELPERS_DIR)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve repo root so script works whether run via root-level symlink or directly
if [[ -d "$SCRIPT_DIR/scripts" && -f "$SCRIPT_DIR/config.json" ]]; then
  REPO_ROOT="$SCRIPT_DIR"
elif [[ -f "$SCRIPT_DIR/../config.json" && -d "$SCRIPT_DIR/../scripts" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  REPO_ROOT="$SCRIPT_DIR"
fi
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$REPO_ROOT/scripts}"
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging dialog file os deps

CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/config.json}"

require_tool() {
  local t="$1"
  if ! command -v "$t" >/dev/null 2>&1; then
    print_error "$t is required but not installed. Run ./setup.sh."
    exit 1
  fi
}

# Resolve download dir and read distros from config.json
load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Config file not found: $CONFIG_FILE"
    exit 1
  fi
  require_tool jq

  DOWNLOAD_DIR=$(jq -r '.download_dir // empty' "$CONFIG_FILE")
  if [[ -z "$DOWNLOAD_DIR" || "$DOWNLOAD_DIR" == "null" ]]; then
    DOWNLOAD_DIR="$HOME/Downloads/iso_images"
  fi
  # Expand ~ if used
  [[ "$DOWNLOAD_DIR" == ~* ]] && DOWNLOAD_DIR="${DOWNLOAD_DIR/#~/$HOME}"
}

# Install required tools if missing using script-helpers
ensure_deps() {
  local pkgs=()
  command -v dialog >/dev/null 2>&1 || pkgs+=(dialog)
  command -v jq >/dev/null 2>&1 || pkgs+=(jq)
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    pkgs+=(curl wget)
  fi
  command -v lsblk >/dev/null 2>&1 || pkgs+=(util-linux)
  if [[ ${#pkgs[@]} -gt 0 ]]; then
    print_info "Installing missing dependencies: ${pkgs[*]}"
    install_dependencies "${pkgs[@]}"
  fi
}

# Download with a dialog gauge progress bar
download_with_progress() {
  local url="$1"; shift
  local output="$1"; shift
  local label="${1:-$output}"
  local total_bytes=0
  local cl
  cl=$(curl -sI -L "$url" | awk 'tolower($1)=="content-length:"{print $2}' | tail -1 | tr -d '\r') || true
  [[ -n "$cl" && "$cl" =~ ^[0-9]+$ ]] && total_bytes=$cl || total_bytes=0

  (
    set +e
    if command -v curl >/dev/null 2>&1; then
      curl -L -o "$output" "$url" &
      pid=$!
    else
      wget -O "$output" "$url" &
      pid=$!
    fi
    while kill -0 "$pid" 2>/dev/null; do
      local size=0 pct=0
      size=$(stat -c %s "$output" 2>/dev/null || echo 0)
      if (( total_bytes > 0 )); then
        pct=$(( size * 100 / total_bytes ))
        (( pct > 99 )) && pct=99
      else
        pct=0
      fi
      echo "XXX"; echo "$pct"; printf "Downloading: %s\n(%s/%s bytes)\n" "$label" "$size" "${total_bytes:-unknown}"; echo "XXX"
      sleep 0.3
    done
    wait "$pid"; status=$?
    echo "$status" >"$REPO_ROOT/.dl_status.tmp"
    echo "XXX"; echo 100; echo "Finalizing..."; echo "XXX"
  ) | dialog --title "Downloading" --gauge "Starting..." 10 "$DIALOG_WIDTH" 0

  local status; status=$(cat "$REPO_ROOT/.dl_status.tmp" 2>/dev/null || echo 1)
  rm -f "$REPO_ROOT/.dl_status.tmp"
  return "$status"
}

ensure_deps
check_if_dialog_installed
dialog_init
load_config
create_directory "$DOWNLOAD_DIR" >/dev/null || true

##############################################################
# Build selection using script-helpers default dialog helpers #
##############################################################
# Prepare associative arrays expected by script-helpers select_* helpers.
# DISTROS is used for display (value shown under each ID), so we map to the
# human-friendly label from config. We also keep a URLS map for later use.
declare -A DISTROS
declare -A URLS

while IFS=$'\t' read -r id label url; do
  [[ -z "$id" || -z "$label" || -z "$url" ]] && continue
  DISTROS["$id"]="$label"
  URLS["$id"]="$url"
done < <(jq -r '.distros[] | "\(.id)\t\(.label)\t\(.url)"' "$CONFIG_FILE")

if [[ ${#DISTROS[@]} -eq 0 ]]; then
  print_error "No distros defined in config.json"
  exit 1
fi

# Use the default multi-select dialog from script-helpers
selected=$(select_multiple_distros) || {
  print_warning "No selection made. Exiting."
  exit 1
}

# The helper returns a space-separated list of quoted IDs; strip quotes.
selected=$(sed 's/\"//g' <<<"$selected")

pushd "$DOWNLOAD_DIR" >/dev/null
errors=0
for id in $selected; do
  url="${URLS[$id]:-}"
  label="${DISTROS[$id]:-}" # human-friendly name for the gauge
  if [[ -z "$url" || "$url" == "null" ]]; then
    print_error "No URL for $id in config.json"; errors=$((errors+1)); continue
  fi
  output=$(basename "$url")
  if [[ "$output" != *.* ]]; then
    output=$(echo "$url" | sed -E 's|.*/([^/]+\.[^/]+)(/.*)?$|\1|')
  fi
  print_info "Downloading $label -> $output"
  # Use the label for the gauge text to show a friendly name
  if ! download_with_progress "$url" "$output" "$label"; then
    print_error "Failed to download $id"
    errors=$((errors+1))
  fi
done
popd >/dev/null

if [[ "$errors" -eq 0 ]]; then
  print_success "Download completed! Files saved to $DOWNLOAD_DIR"
else
  print_warning "Completed with $errors error(s). Check logs."
fi

# End of script
