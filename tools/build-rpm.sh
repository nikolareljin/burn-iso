#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$REPO_ROOT/scripts/script-helpers}"
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging

version="$(cat "$REPO_ROOT/VERSION")"
spec="$REPO_ROOT/packaging/isoforge.spec"
topdir="${RPM_TOPDIR:-$HOME/rpmbuild}"
dist_dir="$REPO_ROOT/dist"
mkdir -p "$dist_dir" "$topdir/SOURCES"

pkg_dir="$topdir/SOURCES/isoforge-$version"
rm -rf "$pkg_dir"
mkdir -p "$pkg_dir"

rsync -a \
  --exclude ".git" \
  --exclude ".github" \
  --exclude "dist" \
  --exclude ".deps_install.log" \
  --exclude ".tmp_config.json" \
  --exclude "test_downloads" \
  "$REPO_ROOT/" "$pkg_dir/"

"$REPO_ROOT/tools/gen-man.sh"

tarball="$topdir/SOURCES/isoforge-$version.tar.gz"
tar -czf "$tarball" -C "$topdir/SOURCES" "isoforge-$version"

rpmbuild -ba "$spec" --define "_topdir $topdir"

find "$topdir/RPMS" -name "*.rpm" -exec cp -f {} "$dist_dir/" \\;
log_info "RPMs copied to $dist_dir"
