#!/usr/bin/env bash
set -euo pipefail

# Install all dependencies for this repo using script-helpers

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
shlib_import logging deps os

print_info "Installing project dependencies via script-helpers ..."

# Default deps cover dialog, curl, jq, wget, util-linux, coreutils (for dd/stat).
# You can pass custom package names as arguments if needed.
if [[ $# -gt 0 ]]; then
  install_dependencies "$@"
else
  # Include common tools for Ventoy workflow and copying
  # exfatprogs/exfat-utils for mounting Ventoy exFAT, rsync for copy with progress
  install_dependencies dialog curl jq wget util-linux coreutils rsync exfatprogs exfat-utils parted
fi

print_success "Dependencies installed."
