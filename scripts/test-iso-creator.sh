#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

base_iso="$tmpdir/base.iso"
: >"$base_iso"
output="$($ROOT_DIR/forge --recipe "$ROOT_DIR/recipes/example.yml" --base-iso "$base_iso" --dry-run 2>&1)"
[[ "$output" == *"$base_iso (local override)"* ]]
