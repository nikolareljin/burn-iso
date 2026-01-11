#!/usr/bin/env bash
set -euo pipefail

# CLI Etcher-like interface using dialog
# Steps: Select Image -> Select Drive -> Flash!

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
source "$REPO_ROOT/inc/setup.sh"
ensure_helpers_library

# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging dialog file os json deps

CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/config.json}"

SELECTED_IMAGE=""
SELECTED_DEVICE=""
DOWNLOAD_DIR=""
DEVICE_FILTER="usb"

require_tool() {
  local t="$1"
  if ! command -v "$t" >/dev/null 2>&1; then
    print_error "$t is required but not installed. Run ./setup.sh."
    exit 1
  fi
}

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Config file not found: $CONFIG_FILE"
    exit 1
  fi
  require_tool jq

  # download dir
  DOWNLOAD_DIR=$(jq -r '.download_dir // empty' "$CONFIG_FILE")
  if [[ -z "$DOWNLOAD_DIR" || "$DOWNLOAD_DIR" == "null" ]]; then
    DOWNLOAD_DIR="$HOME/Downloads/iso_images"
  fi
  # expand ~ at start
  [[ "$DOWNLOAD_DIR" == ~* ]] && DOWNLOAD_DIR="${DOWNLOAD_DIR/#~/$HOME}"

  # device filter (usb|any)
  DEVICE_FILTER=$(jq -r '.block_device_filter // "usb"' "$CONFIG_FILE")
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
  command -v dd >/dev/null 2>&1 || pkgs+=(coreutils)
  if [[ ${#pkgs[@]} -gt 0 ]]; then
    print_info "Installing missing dependencies: ${pkgs[*]}"
    install_dependencies "${pkgs[@]}"
  fi
}

ensure_dialog() {
  check_if_dialog_installed || {
    print_error "Dialog not installed. Run ./setup.sh"
    exit 1
  }
}

title() { echo "Etcher (CLI) — burn-iso"; }

show_summary() {
  local img="${SELECTED_IMAGE:-<not selected>}"
  local dev="${SELECTED_DEVICE:+/dev/$SELECTED_DEVICE}"
  [[ -z "$dev" ]] && dev="<not selected>"
  printf "Image: %s\nDrive: %s\n" "$img" "$dev"
}

select_image_source() {
  dialog_init
  local choice
  choice=$(dialog --stdout --title "$(title)" --menu "Select image source" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 0 \
    download "Choose from curated distros (config.json)" \
    file     "Choose local .iso file" \
    back     "Back") || return 1

  case "$choice" in
    download) select_image_from_config ;;
    file)     select_image_local       ;;
    back)     return 0                 ;;
  esac
}

select_image_local() {
  dialog_init
  local start_dir="${SELECTED_IMAGE:-$HOME}"
  local iso
  iso=$(dialog --stdout --title "$(title) — Select ISO" --fselect "$start_dir/" "$DIALOG_HEIGHT" "$DIALOG_WIDTH") || return 1
  if [[ -z "$iso" ]]; then return 1; fi
  if [[ "${iso,,}" != *.iso ]]; then
    dialog --title "Invalid file" --msgbox "Selected file is not an .iso" 8 50
    return 1
  fi
  SELECTED_IMAGE="$iso"
}

select_image_from_config() {
  dialog_init
  load_config
  create_directory "$DOWNLOAD_DIR" >/dev/null || true

  # Build menu options from config.json
  mapfile -t options < <(jq -r '.distros[] | "\(.id)\t\(.label)"' "$CONFIG_FILE")
  if [[ ${#options[@]} -eq 0 ]]; then
    dialog --title "No distros" --msgbox "No distros defined in config.json" 8 50
    return 1
  fi
  # Flatten into tag/label alternating items for dialog
  local items=()
  local line id label
  for line in "${options[@]}"; do
    id="${line%%$'\t'*}"
    label="${line#*$'\t'}"
    items+=("$id" "$label")
  done

  local chosen
  chosen=$(dialog --stdout --title "$(title) — Choose Distro" --menu "Pick a distro to download" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 0 "${items[@]}") || return 1

  local url output path
  url=$(jq -r --arg id "$chosen" '.distros[] | select(.id==$id) | .url' "$CONFIG_FILE")
  if [[ -z "$url" || "$url" == "null" ]]; then
    dialog --title "Error" --msgbox "No URL found for selected distro." 8 50
    return 1
  fi

  pushd "$DOWNLOAD_DIR" >/dev/null
  # Determine output filename (mirrors scripts/lib/file.sh logic)
  output=$(basename "$url")
  if [[ "$output" != *.* ]]; then
    output=$(echo "$url" | sed -E 's|.*/([^/]+\.[^/]+)(/.*)?$|\1|')
  fi

  # Show a simple info box while downloading
  print_info "Downloading $url -> $output"
  if command -v curl >/dev/null 2>&1; then
    (curl --max-time 3600 -L -o "$output" "$url") 2>/dev/null &
  elif command -v wget >/dev/null 2>&1; then
    (wget --timeout=3600 -O "$output" "$url") 2>/dev/null &
  else
    popd >/dev/null
    dialog --title "Error" --msgbox "Neither curl nor wget is installed." 8 50
    return 1
  fi

  local pid=$!
  dialog --title "Downloading" --infobox "Downloading: $output\nDestination: $DOWNLOAD_DIR" 8 60
  while kill -0 "$pid" 2>/dev/null; do sleep 0.3; done

  if [[ ! -f "$output" ]]; then
    popd >/dev/null
    dialog --title "Error" --msgbox "Download failed for: $output" 8 50
    return 1
  fi

  path="$DOWNLOAD_DIR/$output"
  if is_valid_iso "$path"; then
    SELECTED_IMAGE="$path"
    print_success "Downloaded: $path"
  else
    dialog --title "Warning" --msgbox "Downloaded file is not detected as ISO: $path" 9 60
    SELECTED_IMAGE="$path"
  fi
  popd >/dev/null
}

select_drive() {
  dialog_init
  local rows raw dev type size model tran rm ro
  raw=$(lsblk -dn -o NAME,TYPE,SIZE,MODEL,TRAN,RM,RO -P)
  rows=()
  while IFS= read -r line; do
    # shellcheck disable=SC2001
    dev=$(sed -n 's/.*NAME="\([^"]*\)".*/\1/p' <<<"$line")
    type=$(sed -n 's/.*TYPE="\([^"]*\)".*/\1/p' <<<"$line")
    size=$(sed -n 's/.*SIZE="\([^"]*\)".*/\1/p' <<<"$line")
    model=$(sed -n 's/.*MODEL="\([^"]*\)".*/\1/p' <<<"$line")
    tran=$(sed -n 's/.*TRAN="\([^"]*\)".*/\1/p' <<<"$line")
    rm=$(sed -n 's/.*RM="\([^"]*\)".*/\1/p' <<<"$line")
    ro=$(sed -n 's/.*RO="\([^"]*\)".*/\1/p' <<<"$line")

    [[ "$type" != "disk" ]] && continue
    if [[ "$DEVICE_FILTER" == "usb" ]]; then
      [[ "$tran" != "usb" && "$rm" != "1" ]] && continue
    fi

    rows+=("$dev" "$size ${model:-} [${tran:-n/a}] RO:${ro}")
  done <<<"$raw"

  if [[ ${#rows[@]} -eq 0 ]]; then
    dialog --title "No drives" --msgbox "No suitable drives found (filter: $DEVICE_FILTER)." 8 60
    return 1
  fi

  local chosen
  chosen=$(dialog --stdout --title "$(title) — Select Drive" --menu "Choose destination drive (data will be destroyed)" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 0 "${rows[@]}") || return 1

  # Verify not mounted
  if lsblk "/dev/$chosen" -o MOUNTPOINT -n | grep -q "/"; then
    dialog --title "Drive mounted" --msgbox \
      "Selected drive appears to have mounted partitions.\nPlease unmount all partitions and try again." 9 70
    return 1
  fi

  SELECTED_DEVICE="$chosen"
}

flash_confirm() {
  dialog --stdout --title "Confirm Flash" --yesno \
    "Image:\n  $SELECTED_IMAGE\n\nDrive:\n  /dev/$SELECTED_DEVICE\n\nAll data on the drive will be destroyed. Proceed?" 12 70
}

flash_image() {
  dialog_init
  if [[ -z "${SELECTED_IMAGE:-}" || -z "${SELECTED_DEVICE:-}" ]]; then
    dialog --title "Missing selection" --msgbox "Please select both an image and a drive first." 8 60
    return 1
  fi

  if ! [[ -f "$SELECTED_IMAGE" ]]; then
    dialog --title "Image missing" --msgbox "Selected image not found: $SELECTED_IMAGE" 8 70
    return 1
  fi

  # Confirm
  flash_confirm || return 1

  local dev="/dev/$SELECTED_DEVICE"

  # Size of ISO (Linux/macOS)
  local total
  if command -v stat >/dev/null 2>&1; then
    if stat -c %s "$SELECTED_IMAGE" >/dev/null 2>&1; then
      total=$(stat -c %s "$SELECTED_IMAGE")
    else
      total=$(stat -f%z "$SELECTED_IMAGE")
    fi
  else
    total=0
  fi

  # Build dd command (Linux/macOS)
  local dd_args=(dd if="$SELECTED_IMAGE" of="$dev" bs=4M conv=fsync status=progress)
  local prefix=()
  if command -v sudo >/dev/null 2>&1; then prefix=(sudo); fi

  # Run with a dialog gauge by parsing dd's progress
  (
    set +e
    "${prefix[@]}" "${dd_args[@]}" 2>&1 |
      awk -v total="$total" '
        /^[0-9]+ bytes/ {
          cur=$1; pct=(total>0)?int(cur*100/total):0; if (pct>100)pct=100;
          print "XXX"; print pct; printf("Writing... %s bytes\n", cur); print "XXX"; fflush();
        }
      END { print "XXX"; print 100; print "Finalizing..."; print "XXX"; fflush(); }'
    status=$?
    echo "$status" >"$SCRIPT_DIR/.flash_status.tmp"
  ) | dialog --title "Flashing to $dev" --gauge "Starting..." 12 "$DIALOG_WIDTH" 0

  local status; status=$(cat "$REPO_ROOT/.flash_status.tmp" 2>/dev/null || echo 1)
  rm -f "$REPO_ROOT/.flash_status.tmp"
  sync || true

  if [[ "$status" -eq 0 ]]; then
    dialog --title "Success" --msgbox "Flash completed successfully." 7 40
  else
    dialog --title "Error" --msgbox "Flashing failed. Check permissions and device." 8 60
    return 1
  fi
}

main_menu() {
  # Attempt to install missing dependencies (dialog, jq, curl/wget, util-linux, coreutils)
  ensure_deps
  ensure_dialog
  while true; do
    dialog_init
    local summary; summary=$(show_summary)
    local choice
    choice=$(dialog --stdout --title "$(title)" \
      --menu "${summary}\n\nChoose an action:" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 0 \
      image  "Select Image" \
      drive  "Select Drive" \
      flash  "Flash!" \
      quit   "Quit") || break

    case "$choice" in
      image) select_image_source ;;
      drive) select_drive        ;;
      flash) flash_image         ;;
      quit)  break               ;;
    esac
  done
  clear
}

main_menu "$@"
