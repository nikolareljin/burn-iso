#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

(
  cd "$ROOT_DIR"
  export ISOFORGE_DISABLE_EXIT_TRAP=1
  source ./inc/isoforge.sh

  record_last_download_error \
    "2026-03-11 10:15:00 EDT" \
    "single-download" \
    "Ubuntu_24_04" \
    "https://example.invalid/ubuntu.iso" \
    "/tmp/isoforge-download.test.log" \
    "curl: (22) The requested URL returned error: 404" \
    "22"

  summary="$(show_summary)"
  [[ "$summary" == *"Last download error:"* ]]
  [[ "$summary" == *"single-download Ubuntu_24_04"* ]]
  [[ "$summary" == *"/tmp/isoforge-download.test.log"* ]]
  [[ "$summary" == *"404"* ]]

  clear_last_download_error
  summary="$(show_summary)"
  [[ "$summary" != *"Last download error:"* ]]
)
