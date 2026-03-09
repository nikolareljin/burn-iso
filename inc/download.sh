#!/usr/bin/env bash
set -euo pipefail

# Load shared helpers from submodule in ./scripts (override with SCRIPT_HELPERS_DIR)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve repo root so script works whether run via root-level symlink or directly
if [[ -d "$SCRIPT_DIR/scripts/script-helpers" && -f "$SCRIPT_DIR/config.json" ]]; then
  REPO_ROOT="$SCRIPT_DIR"
elif [[ -f "$SCRIPT_DIR/../config.json" && -d "$SCRIPT_DIR/../scripts/script-helpers" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  REPO_ROOT="$SCRIPT_DIR"
fi
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$REPO_ROOT/scripts/script-helpers}"

if [[ ! -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  >&2 printf "Missing required helper library: %s\n" "$SCRIPT_HELPERS_DIR/helpers.sh"
  >&2 printf "Please install project submodules (e.g. run 'git submodule update --init --recursive') and retry.\n"
  exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging dialog file os deps

# Always restore a clean terminal UI when exiting (including Cancel/interrupt)
reset_tui() { tput cnorm 2>/dev/null || true; tput rmcup 2>/dev/null || true; clear; }
trap reset_tui EXIT INT TERM

CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/config.json}"

require_tool() {
  local t="$1"
  if ! command -v "$t" >/dev/null 2>&1; then
    print_error "$t is required but not installed. Run ./setup.sh."
    exit 1
  fi
}

is_secure_download_url() {
  local url="$1"
  [[ "$url" == https://* ]]
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

ensure_deps
check_if_dialog_installed
dialog_init
load_config
create_directory "$DOWNLOAD_DIR" >/dev/null || true

############################################################
# Build grouped checklist (consistent order + visual headers)
############################################################

# Return category for an id/label pair
distro_category() {
  local id="$1" label="$2" lower="${1,,} ${2,,}"
  if [[ "$lower" == *"raspberry pi"* || "$id" == RaspberryPi_* ]]; then echo "SBC — Raspberry Pi"; return; fi
  if [[ "$id" == Armbian_* || "$lower" == *"armbian"* ]]; then echo "SBC — Armbian / TV Box"; return; fi
  if [[ "$lower" == *"android-x86"* || "$lower" == *"bliss os"* || "$lower" == *"lineageos"* || "$lower" == *"grapheneos"* ]]; then echo "Android / Tablet"; return; fi
  if [[ "$lower" == *"gparted"* || "$lower" == *"rescue"* || "$lower" == *"hiren"* || "$lower" == *"clonezilla"* ]]; then echo "Utilities / Repair"; return; fi
  if [[ "$lower" == *"surface"* || "$lower" == *"xbox"* ]]; then echo "Surface / Xbox"; return; fi
  echo "Desktop / Linux"
}

declare -A DISTROS
declare -A URLS
mapfile -t rows < <(jq -r '.distros[] | "\(.id)\t\(.label)\t\(.url)"' "$CONFIG_FILE")
if [[ ${#rows[@]} -eq 0 ]]; then
  print_error "No distros defined in config.json"
  exit 1
fi

items=()
prev_cat=""
for line in "${rows[@]}"; do
  id="${line%%$'\t'*}"; rest="${line#*$'\t'}"; label="${rest%%$'\t'*}"; url="${line##*$'\t'}"
  DISTROS["$id"]="$label"
  URLS["$id"]="$url"
  cat=$(distro_category "$id" "$label")
  if [[ "$cat" != "$prev_cat" ]]; then
    items+=("hdr_${cat// /_}" "==== $cat ====" off)
    prev_cat="$cat"
  fi
  items+=("$id" "$label" off)
done

selected=$(dialog --stdout --title "Download ISOs" --checklist "Select one or more distros to download" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 0 "${items[@]}") || {
  print_warning "No selection made. Exiting."
  exit 1
}

# dialog returns space-separated quoted ids, e.g., "Ubuntu_24" "Fedora_40"
selected=$(sed 's/\"//g' <<<"$selected")

pushd "$DOWNLOAD_DIR" >/dev/null
errors=0
for id in $selected; do
  # Skip category headers if user selected them
  if [[ "$id" == hdr_* ]]; then continue; fi
  url="${URLS[$id]:-}"
  if [[ -z "$url" || "$url" == "null" ]]; then
    print_error "No URL for $id in config.json"; errors=$((errors+1)); continue
  fi
  if ! is_secure_download_url "$url"; then
    print_error "Skipping $id due to insecure URL scheme (https required): $url"
    errors=$((errors+1))
    continue
  fi
  output=$(basename "$url")
  if [[ "$output" != *.* ]]; then
    output=$(echo "$url" | sed -E 's|.*/([^/]+\.[^/]+)(/.*)?$|\1|')
  fi
  # Script-helpers handles dialog progress + failure details.
  if ! download_file "$url" "$output"; then
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
