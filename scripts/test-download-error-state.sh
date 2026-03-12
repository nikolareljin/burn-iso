#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

(
  cd "$ROOT_DIR"
  export ISOFORGE_DISABLE_EXIT_TRAP=1
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  source ./inc/isoforge.sh

  tmp_log="$tmpdir/error.log"
  record_last_download_error \
    "2026-03-11 10:15:00 EDT" \
    "single-download" \
    "Ubuntu_24_04" \
    "https://example.invalid/ubuntu.iso" \
    "$tmp_log" \
    "curl: (22) The requested URL returned error: 404" \
    "22"

  summary="$(show_summary)"
  [[ "$summary" == *"Last download error:"* ]]
  [[ "$summary" == *"single-download Ubuntu_24_04"* ]]
  [[ "$summary" == *"$tmp_log"* ]]
  [[ "$summary" == *"404"* ]]

  cli_summary="$(print_last_download_error_cli)"
  [[ "$cli_summary" == *"Last download error:"* ]]
  [[ "$cli_summary" == *"$tmp_log"* ]]

  success_file="$tmpdir/success.bin"
  fakebin="$tmpdir/fakebin"
  mkdir -p "$fakebin"
  ln -s "$(command -v bash)" "$fakebin/bash"
  for tool in basename dirname mkdir mktemp mv rm wc date tail; do
    ln -s "$(command -v "$tool")" "$fakebin/$tool"
  done
  cat >"$fakebin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
: >"$out"
EOF
  chmod +x "$fakebin/curl"
  old_path="$PATH"
  set +e
  PATH="$fakebin"
  download_file_with_error_tracking "https://example.invalid/success.bin" "$success_file" "batch-download" "DemoItem"
  success_rc=$?
  PATH="$old_path"
  [[ "$success_rc" -eq 0 ]]
  [[ $- != *e* ]]
  set -e

  cli_summary="$(print_last_download_error_cli)"
  [[ "$cli_summary" == *"Ubuntu_24_04"* ]]
  [[ "$cli_summary" == *"$tmp_log"* ]]

  clear_last_download_error

  mkdir_fail_root="$tmpdir/mkdir-fail"
  fakebin_mkdir_fail="$tmpdir/fakebin-mkdir-fail"
  mkdir -p "$fakebin_mkdir_fail"
  ln -s "$(command -v bash)" "$fakebin_mkdir_fail/bash"
  for tool in basename dirname mktemp mv rm wc date tail; do
    ln -s "$(command -v "$tool")" "$fakebin_mkdir_fail/$tool"
  done
  cat >"$fakebin_mkdir_fail/mkdir" <<'EOF'
#!/usr/bin/env bash
echo "permission denied" >&2
exit 1
EOF
  chmod +x "$fakebin_mkdir_fail/mkdir"
  old_path="$PATH"
  PATH="$fakebin_mkdir_fail"
  if download_file_with_error_tracking "https://example.invalid/mkdir.bin" "$mkdir_fail_root/out.bin" "mkdir-download" "MkdirItem"; then
    echo "expected mkdir failure" >&2
    exit 1
  fi
  PATH="$old_path"
  cli_summary="$(print_last_download_error_cli)"
  [[ "$cli_summary" == *"mkdir-download MkdirItem"* ]]
  [[ "$cli_summary" == *"Failed to create output directory"* ]]

  clear_last_download_error

  cancel_file="$tmpdir/cancel.bin"
  fakebin_dialog="$tmpdir/fakebin-dialog"
  mkdir -p "$fakebin_dialog"
  ln -s "$(command -v bash)" "$fakebin_dialog/bash"
  for tool in basename cat dirname mkdir mktemp mv rm wc date tail sleep; do
    ln -s "$(command -v "$tool")" "$fakebin_dialog/$tool"
  done
  cat >"$fakebin_dialog/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
printf 'partial' >"$out"
sleep 2
EOF
  cat >"$fakebin_dialog/dialog" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null || true
exit 1
EOF
  chmod +x "$fakebin_dialog/curl" "$fakebin_dialog/dialog"
  old_path="$PATH"
  PATH="$fakebin_dialog"
  if download_file_with_error_tracking "https://example.invalid/cancel.bin" "$cancel_file" "dialog-download" "DialogItem"; then
    echo "expected dialog cancellation" >&2
    exit 1
  else
    rc=$?
  fi
  PATH="$old_path"
  [[ "$rc" -eq 1 ]]
  cli_summary="$(print_last_download_error_cli)"
  [[ "$cli_summary" == *"dialog-download DialogItem"* ]]
  [[ "$cli_summary" == *"Download canceled by user via dialog."* ]]

  flow_log="$tmpdir/flow-error.log"
  record_last_download_error \
    "2026-03-11 10:19:00 EDT" \
    "flow-download" \
    "FlowItem" \
    "https://example.invalid/flow.iso" \
    "$flow_log" \
    "flow failure" \
    "1"
  fakebin_flow="$tmpdir/fakebin-flow"
  mkdir -p "$fakebin_flow"
  ln -s "$(command -v bash)" "$fakebin_flow/bash"
  for tool in jq mkdir sed; do
    ln -s "$(command -v "$tool")" "$fakebin_flow/$tool"
  done
  cat >"$fakebin_flow/dialog" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$fakebin_flow/dialog"
  old_path="$PATH"
  old_config_file="$CONFIG_FILE"
  flow_config="$tmpdir/config.json"
  cat >"$flow_config" <<'EOF'
{"distros":[{"id":"DemoISO","label":"Demo ISO","url":"https://example.invalid/demo.iso"}]}
EOF
  CONFIG_FILE="$flow_config"
  PATH="$fakebin_flow"
  select_image_from_config || true
  select_images_from_config_multi || true
  PATH="$old_path"
  CONFIG_FILE="$old_config_file"
  cli_summary="$(print_last_download_error_cli)"
  [[ "$cli_summary" == *"flow-download FlowItem"* ]]
  [[ "$cli_summary" == *"$flow_log"* ]]

  tracked_log="$(mktemp "/tmp/isoforge-download.XXXXXXXX.log")"
  printf 'temporary tracked failure\n' >"$tracked_log"
  record_last_download_error \
    "2026-03-11 10:20:00 EDT" \
    "tracked-download" \
    "TrackedItem" \
    "https://example.invalid/tracked.iso" \
    "$tracked_log" \
    "tracked failure" \
    "1"
  [[ -f "$tracked_log" ]]
  clear_last_download_error
  [[ ! -e "$tracked_log" ]]

  first_tracked_log="$(mktemp "/tmp/isoforge-download.XXXXXXXX.log")"
  second_tracked_log="$(mktemp "/tmp/isoforge-download.XXXXXXXX.log")"
  printf 'first tracked failure\n' >"$first_tracked_log"
  printf 'second tracked failure\n' >"$second_tracked_log"
  record_last_download_error \
    "2026-03-11 10:21:00 EDT" \
    "tracked-download" \
    "TrackedItemOne" \
    "https://example.invalid/tracked-one.iso" \
    "$first_tracked_log" \
    "first tracked failure" \
    "1"
  record_last_download_error \
    "2026-03-11 10:22:00 EDT" \
    "tracked-download" \
    "TrackedItemTwo" \
    "https://example.invalid/tracked-two.iso" \
    "$second_tracked_log" \
    "second tracked failure" \
    "2"
  [[ ! -e "$first_tracked_log" ]]
  [[ -e "$second_tracked_log" ]]

  clear_last_download_error
  [[ ! -e "$second_tracked_log" ]]
  summary="$(show_summary)"
  [[ "$summary" != *"Last download error:"* ]]
)
