#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$REPO_ROOT/scripts/script-helpers}"

# Check before sourcing: with `set -e`, sourcing a missing helpers.sh aborts
# with a bare shell error instead of this message.
if [[ ! -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  echo "ERROR: script-helpers not initialized. Run: git submodule update --init --recursive" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging

helper="$REPO_ROOT/scripts/script-helpers/scripts/publish_homebrew.sh"
if [[ ! -f "$helper" ]]; then
  log_error "Missing script-helpers script: $helper"
  exit 2
fi

exec bash "$helper" \
  --formula "${HOMEBREW_FORMULA_PATH:-$REPO_ROOT/packaging/homebrew/isoforge.rb}" \
  --tap-repo "${HOMEBREW_TAP_REPO:-}" \
  --tap-branch "${HOMEBREW_TAP_BRANCH:-main}" \
  --commit-message "Update isoforge formula"
