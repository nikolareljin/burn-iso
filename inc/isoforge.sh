#!/usr/bin/env bash
# SCRIPT: isoforge.sh
# DESCRIPTION: Isoforge TUI for downloading and flashing ISOs to USB, including Ventoy multi-ISO.
# USAGE: isoforge [--config PATH] [--version] [--help]
# EXAMPLE: isoforge --config ./config.json
# PARAMETERS:
#   --config PATH  Override config file path.
#   --version      Print version and exit.
#   -h, --help     Show help and exit.
# ----------------------------------------------------
set -euo pipefail

# CLI Isoforge-like interface using dialog
# Steps: Select Image -> Select Drive -> Flash!

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISOFORGE_ROOT="${ISOFORGE_ROOT:-}"
if [[ -z "$ISOFORGE_ROOT" && -f "/usr/share/isoforge/config.json" ]]; then
  ISOFORGE_ROOT="/usr/share/isoforge"
fi
if [[ -z "$ISOFORGE_ROOT" ]]; then
  # Resolve repo root so script works whether run via root-level symlink or directly
  if [[ -d "$SCRIPT_DIR/scripts/script-helpers" && -f "$SCRIPT_DIR/config.json" ]]; then
    ISOFORGE_ROOT="$SCRIPT_DIR"
  elif [[ -f "$SCRIPT_DIR/../config.json" && -d "$SCRIPT_DIR/../scripts/script-helpers" ]]; then
    ISOFORGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  else
    ISOFORGE_ROOT="$SCRIPT_DIR"
  fi
fi
REPO_ROOT="$ISOFORGE_ROOT"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$REPO_ROOT/scripts/script-helpers}"

# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging help dialog file os json deps

# Always restore a clean terminal UI when exiting (including Cancel/interrupt)
reset_tui() { tput cnorm 2>/dev/null || true; tput rmcup 2>/dev/null || true; clear; }
trap reset_tui EXIT INT TERM

CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/config.json}"

usage() {
  display_help "$0"
}

VERSION_FILE="$REPO_ROOT/VERSION"
VERSION="${ISOFORGE_VERSION:-}"
if [[ -z "$VERSION" && -f "$VERSION_FILE" ]]; then
  VERSION="$(cat "$VERSION_FILE" 2>/dev/null || true)"
fi
VERSION="${VERSION:-0.1.0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2;;
    --version) echo "$VERSION"; exit 0;;
    -h|--help) usage; exit 0;;
    *) print_error "Unknown argument: $1"; usage; exit 2;;
  esac
done

SELECTED_IMAGE=""
SELECTED_DEVICE=""
DOWNLOAD_DIR=""
DEVICE_FILTER="usb"
# Multi-image (Ventoy) and background support
declare -a SELECTED_IMAGES=()
SELECTED_BACKGROUND=""

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

# Show a minimal TUI gauge while installing dependencies; suppress detailed output to a log.
deps_install_with_dialog() {
  local log="$REPO_ROOT/.deps_install.log"
  : >"$log"
  local status_file="$REPO_ROOT/.deps_status.tmp"
  local pkgs=("$@")
  dialog_init
  (
    set +e
    install_dependencies "${pkgs[@]}" >>"$log" 2>&1 &
    local pid=$!
    local pct=1
    while kill -0 "$pid" 2>/dev/null; do
      pct=$((pct + 3)); (( pct >= 99 )) && pct=1
      echo "XXX"; echo "$pct"; echo "Installing: ${pkgs[*]}"; echo "XXX"
      sleep 0.3
    done
    wait "$pid"; local rc=$?
    echo "$rc" >"$status_file"
    echo "XXX"; echo 100; echo "Finalizing..."; echo "XXX"
  ) | dialog --title "Installing Dependencies" --gauge "Preparing..." 10 "$DIALOG_WIDTH" 0
  local rc; rc=$(cat "$status_file" 2>/dev/null || echo 1)
  rm -f "$status_file"
  return "$rc"
}

# Install required tools if missing using script-helpers (quiet; with TUI progress)
ensure_deps() {
  local log="$REPO_ROOT/.deps_install.log"
  : >"$log"

  # 1) Ensure 'dialog' exists first so we can use TUI for the rest.
  if ! command -v dialog >/dev/null 2>&1; then
    echo "Installing prerequisite: dialog" >>"$log"
    # Best effort; do not spam terminal
    install_dependencies dialog >>"$log" 2>&1 || true
  fi

  # 2) Compute remaining missing dependencies
  local pkgs=()
  command -v jq >/dev/null 2>&1       || pkgs+=(jq)
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    pkgs+=(curl wget)
  fi
  command -v lsblk >/dev/null 2>&1    || pkgs+=(util-linux)
  command -v dd    >/dev/null 2>&1    || pkgs+=(coreutils)
  command -v file  >/dev/null 2>&1    || pkgs+=(file)
  command -v rsync >/dev/null 2>&1    || pkgs+=(rsync)
  command -v unzip >/dev/null 2>&1    || pkgs+=(unzip)
  command -v less  >/dev/null 2>&1    || pkgs+=(less)
  command -v xz    >/dev/null 2>&1    || pkgs+=(xz xz-utils)
  command -v gzip  >/dev/null 2>&1    || pkgs+=(gzip)
  # Optional preview tool: chafa (cross-platform terminal image viewer)
  command -v chafa  >/dev/null 2>&1   || pkgs+=(chafa)

  if [[ ${#pkgs[@]} -gt 0 ]]; then
    if command -v dialog >/dev/null 2>&1; then
      if ! deps_install_with_dialog "${pkgs[@]}"; then
        # Keep details in the log, but inform user with a concise dialog
        dialog --title "Dependencies" --msgbox \
          "Some dependencies failed to install.\n\nYou can review the log at:\n$log" 10 60
      fi
    else
      # Fallback: install quietly without TUI
      install_dependencies "${pkgs[@]}" >>"$log" 2>&1 || true
    fi
  fi
}

ensure_dialog() {
  check_if_dialog_installed || {
    print_error "Dialog not installed. Run ./setup.sh"
    exit 1
  }
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

title() { echo "Isoforge (CLI) — burn-iso"; }

show_summary() {
  local img="${SELECTED_IMAGE:-<not selected>}"
  local dev="${SELECTED_DEVICE:+/dev/$SELECTED_DEVICE}"
  [[ -z "$dev" ]] && dev="<not selected>"
  local multi_count=${#SELECTED_IMAGES[@]}
  [[ $multi_count -gt 1 ]] && img="${multi_count} images (Ventoy)"
  local bg="${SELECTED_BACKGROUND:-<none>}"
  printf "Images: %s\nDrive: %s\nBackground: %s\n" "$img" "$dev" "$bg"
}

select_image_source() {
  dialog_init
  local choice
  choice=$(dialog --stdout --title "$(title)" --menu "Select image source" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 0 \
    download "Choose from curated distros (single download)" \
    download_multi "Choose multiple from curated distros (download)" \
    file     "Choose local .iso file (single)" \
    multi    "Choose multiple local .iso files" \
    back     "Back") || return 1

  case "$choice" in
    download)        select_image_from_config        ;;
    download_multi)  select_images_from_config_multi ;;
    file)            select_image_local              ;;
    multi)           select_images_local_multi       ;;
    back)            return 0                        ;;
  esac
}

# Multi-select from config: download chosen ISOs, then select them
select_images_from_config_multi() {
  dialog_init
  load_config
  create_directory "$DOWNLOAD_DIR" >/dev/null || true
  mapfile -t rows < <(jq -r '.distros[] | "\(.id)\t\(.label)\t\(.url)"' "$CONFIG_FILE")
  if [[ ${#rows[@]} -eq 0 ]]; then
    dialog --title "No distros" --msgbox "No distros defined in config.json" 8 50
    return 1
  fi
  local items=() prev_cat="" id label url cat
  distro_category() {
    local id="$1" label="$2" lower="${1,,} ${2,,}"
    if [[ "$lower" == *"raspberry pi"* || "$id" == RaspberryPi_* ]]; then echo "SBC — Raspberry Pi"; return; fi
    if [[ "$id" == Armbian_* || "$lower" == *"armbian"* ]]; then echo "SBC — Armbian / TV Box"; return; fi
    if [[ "$lower" == *"android-x86"* || "$lower" == *"bliss os"* || "$lower" == *"lineageos"* || "$lower" == *"grapheneos"* ]]; then echo "Android / Tablet"; return; fi
    if [[ "$lower" == *"gparted"* || "$lower" == *"rescue"* || "$lower" == *"hiren"* || "$lower" == *"clonezilla"* ]]; then echo "Utilities / Repair"; return; fi
    if [[ "$lower" == *"surface"* || "$lower" == *"xbox"* ]]; then echo "Surface / Xbox"; return; fi
    echo "Desktop / Linux"
  }
  for line in "${rows[@]}"; do
    id="${line%%$'\t'*}"; rest="${line#*$'\t'}"; label="${rest%%$'\t'*}"; url="${line##*$'\t'}"
    cat=$(distro_category "$id" "$label")
    if [[ "$cat" != "$prev_cat" ]]; then
      items+=("hdr_${cat// /_}" "==== $cat ====" off)
      prev_cat="$cat"
    fi
    items+=("$id" "$label" off)
  done
  local chosen
  chosen=$(dialog --stdout --title "Choose Distros (multi)" --checklist "Pick one or more to download" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 0 "${items[@]}") || return 1
  chosen=$(sed 's/\"//g' <<<"$chosen")
  [[ -z "$chosen" ]] && return 1

  pushd "$DOWNLOAD_DIR" >/dev/null
  SELECTED_IMAGES=()
  local id url output path label errs=0
  for id in $chosen; do
    [[ "$id" == hdr_* ]] && continue
    url=$(jq -r --arg id "$id" '.distros[] | select(.id==$id) | .url' "$CONFIG_FILE")
    label=$(jq -r --arg id "$id" '.distros[] | select(.id==$id) | .label' "$CONFIG_FILE")
    [[ -z "$url" || "$url" == "null" ]] && { errs=$((errs+1)); continue; }
    output=$(basename "$url")
    if [[ "$output" != *.* ]]; then
      output=$(echo "$url" | sed -E 's|.*/([^/]+\.[^/]+)(/.*)?$|\1|')
    fi
    if [[ ! -f "$output" ]]; then
      # No extra prints; show only dialog during download
      download_with_progress "$url" "$output" "${label:-$output}" || errs=$((errs+1))
    fi
    path="$DOWNLOAD_DIR/$output"
    if [[ -f "$path" ]]; then SELECTED_IMAGES+=("$path"); fi
  done
  popd >/dev/null
  if [[ ${#SELECTED_IMAGES[@]} -eq 1 ]]; then
    SELECTED_IMAGE="${SELECTED_IMAGES[0]}"
  elif [[ ${#SELECTED_IMAGES[@]} -gt 1 ]]; then
    SELECTED_IMAGE=""
  else
    dialog --title "Download" --msgbox "No files downloaded/selected." 7 40
    return 1
  fi
}

# Multi-select local ISOs from download directory
select_images_local_multi() {
  dialog_init
  load_config
  create_directory "$DOWNLOAD_DIR" >/dev/null || true
  mapfile -t files < <(find "$DOWNLOAD_DIR" -maxdepth 1 -type f -iname "*.iso" 2>/dev/null | sort)
  if [[ ${#files[@]} -eq 0 ]]; then
    dialog --title "No ISOs" --msgbox "No ISO files found in $DOWNLOAD_DIR. Run ./download to fetch images first." 9 70
    return 1
  fi
  local items=()
  local p base
  for p in "${files[@]}"; do
    base=$(basename "$p")
    items+=("$p" "$base" off)
  done
  local selected
  selected=$(dialog --stdout --title "Select ISOs (Ventoy)" --checklist "Choose one or more images to copy via Ventoy" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 0 "${items[@]}") || return 1
  selected=$(sed 's/\"//g' <<<"$selected")
  SELECTED_IMAGES=()
  for p in $selected; do SELECTED_IMAGES+=("$p"); done
  if [[ ${#SELECTED_IMAGES[@]} -eq 1 ]]; then
    SELECTED_IMAGE="${SELECTED_IMAGES[0]}"
  elif [[ ${#SELECTED_IMAGES[@]} -gt 1 ]]; then
    SELECTED_IMAGE=""
  fi
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

  # Build grouped menu options from config.json
  mapfile -t rows < <(jq -r '.distros[] | "\(.id)\t\(.label)\t\(.url)"' "$CONFIG_FILE")
  if [[ ${#rows[@]} -eq 0 ]]; then
    dialog --title "No distros" --msgbox "No distros defined in config.json" 8 50
    return 1
  fi
  # Flatten into tag/label alternating items for dialog, with headers
  local items=() prev_cat="" id label url cat
  distro_category() {
    local id="$1" label="$2" lower="${1,,} ${2,,}"
    if [[ "$lower" == *"raspberry pi"* || "$id" == RaspberryPi_* ]]; then echo "SBC — Raspberry Pi"; return; fi
    if [[ "$id" == Armbian_* || "$lower" == *"armbian"* ]]; then echo "SBC — Armbian / TV Box"; return; fi
    if [[ "$lower" == *"android-x86"* || "$lower" == *"bliss os"* || "$lower" == *"lineageos"* || "$lower" == *"grapheneos"* ]]; then echo "Android / Tablet"; return; fi
    if [[ "$lower" == *"gparted"* || "$lower" == *"rescue"* || "$lower" == *"hiren"* || "$lower" == *"clonezilla"* ]]; then echo "Utilities / Repair"; return; fi
    if [[ "$lower" == *"surface"* || "$lower" == *"xbox"* ]]; then echo "Surface / Xbox"; return; fi
    echo "Desktop / Linux"
  }
  for line in "${rows[@]}"; do
    id="${line%%$'\t'*}"; rest="${line#*$'\t'}"; label="${rest%%$'\t'*}"; url="${line##*$'\t'}"
    cat=$(distro_category "$id" "$label")
    if [[ "$cat" != "$prev_cat" ]]; then
      items+=("hdr_${cat// /_}" "==== $cat ====")
      prev_cat="$cat"
    fi
    items+=("$id" "$label")
  done

  local chosen
  while true; do
    chosen=$(dialog --stdout --title "$(title) — Choose Distro" --menu "Pick a distro to download" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 0 "${items[@]}") || return 1
    [[ "$chosen" == hdr_* ]] && continue
    break
  done

  local url output path label
  url=$(jq -r --arg id "$chosen" '.distros[] | select(.id==$id) | .url' "$CONFIG_FILE")
  label=$(jq -r --arg id "$chosen" '.distros[] | select(.id==$id) | .label' "$CONFIG_FILE")
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

  # Avoid extra stdout noise during the dialog gauge
  if ! download_with_progress "$url" "$output" "${label:-$output}"; then
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
    "Images:\n  $( if [[ ${#SELECTED_IMAGES[@]} -gt 1 ]]; then echo "${#SELECTED_IMAGES[@]} selected (Ventoy)"; else echo "${SELECTED_IMAGE:-<not selected>}"; fi )\n\nDrive:\n  /dev/$SELECTED_DEVICE\n\nAll data on the drive will be destroyed. Proceed?" 12 70
}

flash_image() {
  dialog_init
  if [[ -z "${SELECTED_DEVICE:-}" ]]; then
    dialog --title "Missing selection" --msgbox "Please select a drive first." 8 60
    return 1
  fi
  if [[ ${#SELECTED_IMAGES[@]} -gt 1 ]]; then
    flash_with_ventoy || return 1
    return 0
  fi
  if [[ -z "${SELECTED_IMAGE:-}" ]]; then
    dialog --title "Missing selection" --msgbox "Please select an image first." 8 60
    return 1
  fi
  if ! [[ -f "$SELECTED_IMAGE" ]]; then
    dialog --title "Image missing" --msgbox "Selected image not found: $SELECTED_IMAGE" 8 70
    return 1
  fi
  flash_confirm || return 1
  local dev="/dev/$SELECTED_DEVICE"
  local total
  if stat -c %s "$SELECTED_IMAGE" >/dev/null 2>&1; then
    total=$(stat -c %s "$SELECTED_IMAGE")
  else
    total=$(stat -f%z "$SELECTED_IMAGE" 2>/dev/null || echo 0)
  fi

  # Handle compressed images by streaming decompression to dd
  local lower_img="${SELECTED_IMAGE,,}" use_stream=false stream_cmd=()
  if [[ "$lower_img" == *.img.xz || "$lower_img" == *.xz ]]; then
    if command -v xz >/dev/null 2>&1; then
      stream_cmd=(xz -dc "$SELECTED_IMAGE")
      use_stream=true
      total=0
    else
      dialog --title "Missing tool" --msgbox "xz not found to decompress image. Install xz/xz-utils and try again." 9 60
      return 1
    fi
  elif [[ "$lower_img" == *.img.gz || "$lower_img" == *.gz ]]; then
    if command -v gzip >/dev/null 2>&1; then
      stream_cmd=(gzip -dc "$SELECTED_IMAGE")
      use_stream=true
      total=0
    else
      dialog --title "Missing tool" --msgbox "gzip not found to decompress image." 7 50
      return 1
    fi
  fi

  local dd_args
  if $use_stream; then
    dd_args=(dd of="$dev" bs=4M conv=fsync status=progress)
  else
    dd_args=(dd if="$SELECTED_IMAGE" of="$dev" bs=4M conv=fsync status=progress)
  fi
  local prefix=(); command -v sudo >/dev/null 2>&1 && prefix=(sudo)
  (
    set +e
    if $use_stream; then
      "${stream_cmd[@]}" | "${prefix[@]}" "${dd_args[@]}" 2>&1 |
      awk -v total="$total" '
        /^[0-9]+ bytes/ {
          cur=$1; pct=(total>0)?int(cur*100/total):0; if (pct>100)pct=100;
          print "XXX"; print pct; printf("Writing (decompressing)... %s bytes\n", cur); print "XXX"; fflush();
        }
      END { print "XXX"; print 100; print "Finalizing..."; print "XXX"; fflush(); }'
    else
      "${prefix[@]}" "${dd_args[@]}" 2>&1 |
      awk -v total="$total" '
        /^[0-9]+ bytes/ {
          cur=$1; pct=(total>0)?int(cur*100/total):0; if (pct>100)pct=100;
          print "XXX"; print pct; printf("Writing... %s bytes\n", cur); print "XXX"; fflush();
        }
      END { print "XXX"; print 100; print "Finalizing..."; print "XXX"; fflush(); }'
    fi
    status=$?
    echo "$status" >"$REPO_ROOT/.flash_status.tmp"
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

# --- Ventoy support ---
flash_with_ventoy() {
  if [[ ${#SELECTED_IMAGES[@]} -lt 2 ]]; then return 1; fi
  ensure_ventoy_available || return 1
  local dev="/dev/$SELECTED_DEVICE"
  local prefix=(); command -v sudo >/dev/null 2>&1 && prefix=(sudo)
  flash_confirm || return 1
  (
    set -e
    "${prefix[@]}" bash "$VENTOY_BIN" -I -g "$dev"
    echo $? >"$REPO_ROOT/.ventoy_status.tmp"
  ) | dialog --title "Installing Ventoy" --gauge "Preparing device ..." 10 "$DIALOG_WIDTH" 0
  local vstatus; vstatus=$(cat "$REPO_ROOT/.ventoy_status.tmp" 2>/dev/null || echo 1)
  rm -f "$REPO_ROOT/.ventoy_status.tmp"
  if [[ "$vstatus" -ne 0 ]]; then
    dialog --title "Ventoy" --msgbox "Ventoy installation failed." 7 40
    return 1
  fi
  local part mnt
  part=$(lsblk -ln -o NAME,TYPE "/dev/$SELECTED_DEVICE" | awk '$2=="part"{print $1}' | head -1)
  if [[ -z "$part" ]]; then
    dialog --title "Ventoy" --msgbox "Could not locate Ventoy data partition." 7 60
    return 1
  fi
  mnt=$(lsblk -no MOUNTPOINT "/dev/$part" | head -1)
  if [[ -z "$mnt" ]]; then
    mnt="$REPO_ROOT/.mnt_ventoy"; mkdir -p "$mnt"
    if ! "${prefix[@]}" mount "/dev/$part" "$mnt"; then
      dialog --title "Ventoy" --msgbox "Failed to mount /dev/$part. Ensure exFAT support is installed (exfatprogs/exfat-utils)." 9 70
      return 1
    fi
  fi
  if [[ -n "$SELECTED_BACKGROUND" && -f "$SELECTED_BACKGROUND" ]]; then
    apply_ventoy_background "$mnt" "$SELECTED_BACKGROUND" || return 1
  fi
  if ! ensure_space_or_prune "$mnt"; then return 1; fi
  copy_isos_to_ventoy "$mnt" || return 1
  sync || true
  dialog --title "Success" --msgbox "Ventoy prepared and ISOs copied successfully." 7 60
}

ensure_ventoy_available() {
  VENTOY_BIN=""
  local cand
  for cand in "$REPO_ROOT/ventoy/Ventoy2Disk.sh" "$REPO_ROOT/tools/ventoy/Ventoy2Disk.sh" "$REPO_ROOT/Ventoy2Disk.sh"; do
    [[ -x "$cand" ]] && VENTOY_BIN="$cand" && break
  done
  if [[ -z "$VENTOY_BIN" ]] && command -v Ventoy2Disk.sh >/dev/null 2>&1; then
    VENTOY_BIN=$(command -v Ventoy2Disk.sh)
  fi
  if [[ -z "$VENTOY_BIN" ]]; then
    # Try to install via system package manager first
    if command -v apt-get >/dev/null 2>&1; then
      print_info "Installing ventoy via apt-get ..."
      if sudo apt-get update && sudo apt-get install -y ventoy; then
        if command -v Ventoy2Disk.sh >/dev/null 2>&1; then VENTOY_BIN=$(command -v Ventoy2Disk.sh); fi
      fi
    elif command -v dnf >/dev/null 2>&1; then
      print_info "Installing ventoy via dnf ..."
      sudo dnf install -y ventoy || true
      if command -v Ventoy2Disk.sh >/dev/null 2>&1; then VENTOY_BIN=$(command -v Ventoy2Disk.sh); fi
    elif command -v pacman >/dev/null 2>&1; then
      print_info "Installing ventoy via pacman ..."
      sudo pacman -S --noconfirm ventoy || true
      if command -v Ventoy2Disk.sh >/dev/null 2>&1; then VENTOY_BIN=$(command -v Ventoy2Disk.sh); fi
    fi
  fi
  if [[ -z "$VENTOY_BIN" ]]; then
    # Download latest Ventoy release from GitHub
    print_info "Downloading Ventoy (latest) ..."
    local api="https://api.github.com/repos/ventoy/Ventoy/releases/latest"
    local tag ver url tmpdir tarball outdir
    tmpdir="$(mktemp -d)"
    if curl -fsSL "$api" -o "$tmpdir/latest.json"; then
      tag=$(jq -r .tag_name "$tmpdir/latest.json" 2>/dev/null || echo "")
      ver="${tag#v}"
      if [[ -n "$ver" ]]; then
        url="https://github.com/ventoy/Ventoy/releases/download/${tag}/ventoy-${ver}-linux.tar.gz"
        mkdir -p "$REPO_ROOT/ventoy"
        if curl -fL "$url" -o "$tmpdir/ventoy.tgz"; then
          tar -xzf "$tmpdir/ventoy.tgz" -C "$REPO_ROOT/ventoy" || true
          outdir=$(find "$REPO_ROOT/ventoy" -maxdepth 1 -type d -name "ventoy-*" | head -1)
          if [[ -x "$outdir/Ventoy2Disk.sh" ]]; then
            VENTOY_BIN="$outdir/Ventoy2Disk.sh"
          fi
        fi
      fi
    fi
    rm -rf "$tmpdir"
  fi
  if [[ -z "$VENTOY_BIN" ]]; then
    dialog --title "Ventoy not found" --msgbox "Could not locate or auto-install Ventoy.\nPlease install Ventoy and ensure Ventoy2Disk.sh is available.\nRef: https://www.ventoy.net/en/download.html" 11 70
    return 1
  fi
  return 0
}

apply_ventoy_background() {
  local mnt="$1"; shift
  local img="$1"
  local vdir="$mnt/ventoy/theme/default"
  mkdir -p "$vdir"
  local ext="${img##*.}"; ext="${ext,,}"
  case "$ext" in
    jpg|jpeg|png|tga) :;;
    *) dialog --title "Background" --msgbox "Unsupported image format: .$ext. Use jpg/png/tga." 8 60; return 1;;
  esac
  local bg="$vdir/background.$ext"
  cp -f "$img" "$bg"
  cat >"$vdir/theme.txt" <<EOF
desktop-image: "background.$ext"
title-text: "Ventoy"
EOF
  mkdir -p "$mnt/ventoy"
  cat >"$mnt/ventoy/ventoy.json" <<EOF
{
  "theme": {
    "file": "/ventoy/theme/default/theme.txt",
    "gfxmode": "auto",
    "display_mode": "GUI"
  }
}
EOF
}

ensure_space_or_prune() {
  local mnt="$1"
  local total=0 f size
  for f in "${SELECTED_IMAGES[@]}"; do
    size=$(stat -c %s "$f" 2>/dev/null || echo 0)
    total=$((total + size))
  done
  local avail_kb; avail_kb=$(df -Pk "$mnt" | awk 'END{print $4}')
  local avail=$((avail_kb * 1024))
  if (( total <= avail )); then return 0; fi
  local items=()
  for f in "${SELECTED_IMAGES[@]}"; do items+=("$f" "$(basename "$f")" on); done
  local sel; sel=$(dialog --stdout --title "Insufficient space" --checklist "Available: $((avail/1024/1024)) MiB\nRequired: $((total/1024/1024)) MiB\nDeselect some ISOs:" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 0 "${items[@]}") || return 1
  sel=$(sed 's/\"//g' <<<"$sel")
  local new=(); for f in $sel; do new+=("$f"); done
  [[ ${#new[@]} -eq 0 ]] && return 1
  SELECTED_IMAGES=("${new[@]}")
  # recheck
  total=0; for f in "${SELECTED_IMAGES[@]}"; do size=$(stat -c %s "$f" 2>/dev/null || echo 0); total=$((total + size)); done
  (( total <= avail )) || ensure_space_or_prune "$mnt"
}

copy_isos_to_ventoy() {
  local mnt="$1"; shift
  local f
  for f in "${SELECTED_IMAGES[@]}"; do
    local base; base=$(basename "$f")
    if command -v rsync >/dev/null 2>&1; then
      rsync -h --progress "$f" "$mnt/$base" || return 1
    else
      cp -v "$f" "$mnt/$base" || return 1
    fi
  done
}

select_background_image() {
  dialog_init
  local start_dir="${DOWNLOAD_DIR:-$HOME}"
  local img
  img=$(dialog --stdout --title "Select Background Image (jpg/png/tga)" --fselect "$start_dir/" "$DIALOG_HEIGHT" "$DIALOG_WIDTH") || return 1
  [[ -z "$img" ]] && return 1
  local lower="${img,,}"
  if [[ "$lower" != *.jpg && "$lower" != *.jpeg && "$lower" != *.png && "$lower" != *.tga ]]; then
    dialog --title "Invalid file" --msgbox "Select a jpg/png/tga image." 7 40
    return 1
  fi
  SELECTED_BACKGROUND="$img"
  ensure_image_view_available
  local viewer=""
  for viewer in "$REPO_ROOT/image-view/image-view" "$REPO_ROOT/image-view/bin/image-view"; do
    [[ -x "$viewer" ]] && break || viewer=""
  done
  if [[ -n "$viewer" ]]; then
    # Launch external viewer; user closes it normally (e.g., window close or ESC if supported)
    "$viewer" "$SELECTED_BACKGROUND" || true
    return 0
  fi

  if command -v chafa >/dev/null 2>&1; then
    # Render preview in the terminal and keep it open in less until user presses 'q' to quit.
    # This provides a simple "press q to close" interaction.
    local err_file; err_file="$(mktemp)"
    set +e
    chafa "$SELECTED_BACKGROUND" 2>"$err_file" | less -R
    local chafa_rc=${PIPESTATUS[0]}
    set -e
    if [[ $chafa_rc -ne 0 ]]; then
      local emsg; emsg=$(cat "$err_file")
      rm -f "$err_file"
      dialog --title "chafa error" --msgbox "Failed to preview image with 'chafa'.\n\nError:\n${emsg}" 12 70
      return 1
    fi
    rm -f "$err_file"
    return 0
  fi

  print_warning "No preview tool available (image-view/chafa). Skipping preview."
}

# Ensure an image-view binary is available; try to download a release asset for current OS/arch
ensure_image_view_available() {
  local bin
  for bin in "$REPO_ROOT/image-view/image-view" "$REPO_ROOT/image-view/bin/image-view"; do
    [[ -x "$bin" ]] && return 0
  done
  mkdir -p "$REPO_ROOT/image-view"
  # Detect OS/arch (linux only)
  local os="linux" arch
  arch=$(uname -m | tr '[:upper:]' '[:lower:]')
  case "$arch" in
    x86_64|amd64) arch_tag="amd64|x86_64" ;;
    aarch64|arm64) arch_tag="arm64|aarch64" ;;
    *) arch_tag="$arch" ;;
  esac
  local api="https://api.github.com/repos/nikolareljin/image-view/releases/latest"
  local tmpdir; tmpdir=$(mktemp -d)
  if curl -fsSL "$api" -o "$tmpdir/latest.json"; then
    local url name
    url=$(jq -r --arg os "$os" --arg arch "$arch_tag" '.assets[] | select((.name|test($os; "i")) and (.name|test($arch; "i"))) | .browser_download_url' "$tmpdir/latest.json" | head -1)
    name=$(jq -r --arg os "$os" --arg arch "$arch_tag" '.assets[] | select((.name|test($os; "i")) and (.name|test($arch; "i"))) | .name' "$tmpdir/latest.json" | head -1)
    if [[ -n "$url" ]]; then
      local dest="$tmpdir/$name"
      if curl -fL "$url" -o "$dest"; then
        if [[ "$name" =~ \.(tar\.gz|tgz)$ ]]; then
          mkdir -p "$tmpdir/extract"
          tar -xzf "$dest" -C "$tmpdir/extract" || true
          local found
          found=$(find "$tmpdir/extract" -type f -perm -111 -iname 'image-view*' | head -1)
          if [[ -n "$found" ]]; then
            cp "$found" "$REPO_ROOT/image-view/image-view" && chmod +x "$REPO_ROOT/image-view/image-view"
          fi
        elif [[ "$name" =~ \.zip$ ]]; then
          command -v unzip >/dev/null 2>&1 && unzip -o "$dest" -d "$tmpdir/extract" || true
          local found
          found=$(find "$tmpdir/extract" -type f -perm -111 -iname 'image-view*' | head -1)
          if [[ -n "$found" ]]; then
            cp "$found" "$REPO_ROOT/image-view/image-view" && chmod +x "$REPO_ROOT/image-view/image-view"
          fi
        else
          cp "$dest" "$REPO_ROOT/image-view/image-view" && chmod +x "$REPO_ROOT/image-view/image-view"
        fi
      fi
    fi
  fi
  rm -rf "$tmpdir"
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
      image  "Select Image(s)" \
      bg     "Select Ventoy Background" \
      drive  "Select Drive" \
      flash  "Flash! (dd for single, Ventoy for multi)" \
      quit   "Quit") || break

    case "$choice" in
      image) select_image_source ;;
      bg)    select_background_image ;;
      drive) select_drive        ;;
      flash) flash_image         ;;
      quit)  break               ;;
    esac
  done
  clear
}

main_menu "$@"
