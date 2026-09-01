#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$REPO_ROOT/scripts/script-helpers}"
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging

helper="$REPO_ROOT/scripts/script-helpers/scripts/gen_brew_formula.sh"
if [[ -f "$helper" ]]; then
  version="$(cat "$REPO_ROOT/VERSION")"
  tarball="${TARBALL_PATH:-$REPO_ROOT/dist/isoforge-$version.tar.gz}"
  if [[ ! -f "$tarball" ]]; then
    log_error "Tarball not found: $tarball"
    exit 2
  fi

  url="${TARBALL_URL:-https://github.com/nikolareljin/iso-forge/releases/download/$version/isoforge-$version.tar.gz}"
  formula="$REPO_ROOT/packaging/homebrew/isoforge.rb"
  bash "$helper" \
    --name "isoforge" \
    --desc "TUI tool for downloading and flashing ISO images to USB" \
    --homepage "https://github.com/nikolareljin/iso-forge" \
    --license "MIT" \
    --tarball "$tarball" \
    --url "$url" \
    --dep "dialog" \
    --dep "jq" \
    --dep "curl" \
    --entrypoint "inc/isoforge.sh" \
    --man-path "docs/man/isoforge.1" \
    --formula-path "$formula" \
    --use-libexec \
    --env-var "ISOFORGE_ROOT"

  # script-helpers gen_brew_formula.sh emits the dependency block through a
  # heredoc, so its "\n" separators stay literal, and it names the bin shim
  # after --entrypoint, which yields bin/"inc/isoforge.sh" instead of
  # bin/"isoforge". Repair both until the helper is fixed upstream.
  sed -i 's/\\n/\n/g' "$formula"
  sed -i 's|(bin/"inc/isoforge.sh")|(bin/"isoforge")|' "$formula"
  log_info "Wrote Homebrew formula: $formula"
  exit 0
fi

log_error "script-helpers not initialized. Run: git submodule update --init --recursive"
exit 2
