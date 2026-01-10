#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$REPO_ROOT/scripts/script-helpers}"
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging

helper="$REPO_ROOT/scripts/script-helpers/scripts/build_deb_artifacts.sh"
if [[ -x "$helper" ]]; then
  "$REPO_ROOT/tools/gen-man.sh"
  exec "$helper" --repo "$REPO_ROOT"
fi

log_error "script-helpers not initialized. Run: git submodule update --init --recursive"
exit 2
