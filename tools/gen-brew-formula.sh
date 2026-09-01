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

helper="$REPO_ROOT/scripts/script-helpers/scripts/gen_brew_formula.sh"
if [[ ! -f "$helper" ]]; then
  log_error "Missing script-helpers script: $helper"
  exit 2
fi

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
# bin/"isoforge". Repair both until the helper is fixed upstream. awk with a
# temporary file keeps this working on BSD/macOS, where sed -i needs an
# argument and does not expand \n in a replacement.
awk '{
  gsub(/\\n/, "\n")
  gsub(/\(bin\/"inc\/isoforge\.sh"\)/, "(bin/\"isoforge\")")
  print
}' "$formula" >"$formula.tmp"
mv "$formula.tmp" "$formula"
log_info "Wrote Homebrew formula: $formula"
