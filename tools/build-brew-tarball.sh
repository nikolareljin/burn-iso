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

helper="$REPO_ROOT/scripts/script-helpers/scripts/build_brew_tarball.sh"
if [[ ! -f "$helper" ]]; then
  log_error "Missing script-helpers script: $helper"
  exit 2
fi

exec bash "$helper" \
  --name "isoforge" \
  --repo "$REPO_ROOT" \
  --dist-dir "$REPO_ROOT/dist" \
  --exclude ".git" \
  --exclude ".github" \
  --exclude "dist" \
  --exclude ".deps_install.log" \
  --exclude ".tmp_config.json" \
  --exclude ".mockbin" \
  --exclude "test_downloads"
