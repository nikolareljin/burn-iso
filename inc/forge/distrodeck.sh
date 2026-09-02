#!/usr/bin/env bash
# Reading a distrodeck export as a package list.
#
# The export format is a stable INI-with-sections file (distrodeck's
# examples/distrodeck-export.txt). Parsing it directly rather than running
# `distrodeck import` is deliberate: import targets a running system, expects
# to manage sources and offer a revert, and none of that is meaningful for a
# root filesystem that has never booted.

FORGE_DD_APT=()
FORGE_DD_PPAS=()
FORGE_DD_SOURCES=()
FORGE_DD_FLATPAK=()
FORGE_DD_SNAP=()

# Emits the body of one [section], skipping comments and blank lines.
forge_dd_section() {
  local file="$1" want="$2"
  awk -v want="[$want]" '
    /^\[/    { inside = ($0 == want); next }
    !inside  { next }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { print }
  ' "$file"
}

forge_dd_load() {
  local file="$1"
  local -a wanted=("${@:2}")

  file="${file/#\~/$HOME}"
  if [[ ! -f "$file" ]]; then
    log_error "distrodeck export not found: $file"
    return 2
  fi

  local header
  header=$(head -1 "$file")
  if [[ "$header" != "# distrodeck export"* ]]; then
    log_error "Not a distrodeck export (first line should say '# distrodeck export v1'): $file"
    return 2
  fi

  # No explicit section list means take the ones that can be applied offline.
  if ((${#wanted[@]} == 0)); then
    wanted=(apt_manual ppas apt_sources flatpak)
  fi

  FORGE_DD_APT=(); FORGE_DD_PPAS=(); FORGE_DD_SOURCES=(); FORGE_DD_FLATPAK=(); FORGE_DD_SNAP=()

  local section
  for section in "${wanted[@]}"; do
    case "$section" in
      apt_manual)  mapfile -t -O "${#FORGE_DD_APT[@]}"     FORGE_DD_APT     < <(forge_dd_section "$file" apt_manual) ;;
      ppas)        mapfile -t -O "${#FORGE_DD_PPAS[@]}"    FORGE_DD_PPAS    < <(forge_dd_section "$file" ppas) ;;
      apt_sources) mapfile -t -O "${#FORGE_DD_SOURCES[@]}" FORGE_DD_SOURCES < <(forge_dd_section "$file" apt_sources) ;;
      flatpak)     mapfile -t -O "${#FORGE_DD_FLATPAK[@]}" FORGE_DD_FLATPAK < <(forge_dd_section "$file" flatpak) ;;
      snap)        mapfile -t -O "${#FORGE_DD_SNAP[@]}"    FORGE_DD_SNAP    < <(forge_dd_section "$file" snap) ;;
      apt_hold|pacman|dnf|zypper|appimage)
        log_warn "distrodeck section '$section' is not applied to an image; skipping."
        ;;
      *)
        log_warn "Unknown distrodeck section '$section'; skipping."
        ;;
    esac
  done

  log_info "distrodeck export: ${#FORGE_DD_APT[@]} apt, ${#FORGE_DD_PPAS[@]} ppa, ${#FORGE_DD_SOURCES[@]} source, ${#FORGE_DD_FLATPAK[@]} flatpak"

  # snapd cannot install into a chroot: it needs its own mount namespace and a
  # running snapd. Saying so is better than a build that quietly drops them.
  if ((${#FORGE_DD_SNAP[@]})); then
    log_warn "${#FORGE_DD_SNAP[@]} snap(s) in the export cannot be installed into an image."
    log_warn "Seed them on first boot instead; see docs/BUILD.md."
  fi
}

# distrodeck writes flatpak lines as "remote=flathub app=org.gimp.GIMP".
forge_dd_flatpak_fields() {
  local line="$1" key="$2"
  awk -v k="$key=" '{ for (i = 1; i <= NF; i++) if (index($i, k) == 1) { print substr($i, length(k) + 1); exit } }' <<<"$line"
}
