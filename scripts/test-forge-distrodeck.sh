#!/usr/bin/env bash
# Reading a distrodeck export as a package list.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$REPO_ROOT/scripts/script-helpers}"

if [[ ! -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  echo "script-helpers not initialized; run ./update" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging
# shellcheck source=/dev/null
source "$REPO_ROOT/inc/forge/distrodeck.sh"

pass=0
fail=0
ok()  { printf 'ok   - %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL - %s\n' "$1"; fail=$((fail + 1)); }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The format distrodeck actually writes; see its examples/distrodeck-export.txt.
cat >"$TMP/export.txt" <<'EOF'
# distrodeck export v1
exported_at=2024-01-01T00:00:00Z
distro_id=ubuntu
codename=jammy

[apt_manual]
curl
nala
# a comment inside a section
tmux

[apt_hold]

[ppas]
ppa:graphics-drivers/ppa

[apt_sources]
deb [signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable

[snap]
firefox channel=latest/stable classic=false

[flatpak]
remote=flathub app=org.gimp.GIMP

[pacman]

[appimage]
/home/user/Applications/Example.AppImage
EOF

forge_dd_load "$TMP/export.txt" apt_manual ppas apt_sources flatpak snap >/dev/null 2>&1

check "apt_manual entries are read"      "${#FORGE_DD_APT[@]}"     "3"
check "comments inside a section are skipped" "$(printf '%s,' "${FORGE_DD_APT[@]}")" "curl,nala,tmux,"
check "ppas are read"                    "${#FORGE_DD_PPAS[@]}"    "1"
check "apt_sources are read"             "${#FORGE_DD_SOURCES[@]}" "1"
check "flatpak entries are read"         "${#FORGE_DD_FLATPAK[@]}" "1"
check "an empty section yields nothing"  "$(forge_dd_section "$TMP/export.txt" apt_hold | wc -l | tr -d ' ')" "0"

# distrodeck writes flatpak lines as key=value pairs.
check "the flatpak remote is parsed" "$(forge_dd_flatpak_fields "${FORGE_DD_FLATPAK[0]}" remote)" "flathub"
check "the flatpak app is parsed"    "$(forge_dd_flatpak_fields "${FORGE_DD_FLATPAK[0]}" app)"    "org.gimp.GIMP"

# Sections that cannot be applied to an image must not be silently mixed in.
forge_dd_load "$TMP/export.txt" >/dev/null 2>&1
check "the default section set excludes snap" "${#FORGE_DD_SNAP[@]}" "0"
check "the default section set includes apt"  "${#FORGE_DD_APT[@]}"  "3"

# A file that is not an export should be refused rather than parsed as empty.
printf 'just some text\n' >"$TMP/not-an-export.txt"
if forge_dd_load "$TMP/not-an-export.txt" >/dev/null 2>&1; then
  bad "a file with no distrodeck header is rejected"
else
  ok "a file with no distrodeck header is rejected"
fi

if forge_dd_load "$TMP/missing.txt" >/dev/null 2>&1; then
  bad "a missing export is rejected"
else
  ok "a missing export is rejected"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
