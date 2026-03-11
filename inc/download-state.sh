#!/usr/bin/env bash

LAST_DOWNLOAD_ERROR_TIME="${LAST_DOWNLOAD_ERROR_TIME:-}"
LAST_DOWNLOAD_ERROR_OPERATION="${LAST_DOWNLOAD_ERROR_OPERATION:-}"
LAST_DOWNLOAD_ERROR_SOURCE="${LAST_DOWNLOAD_ERROR_SOURCE:-}"
LAST_DOWNLOAD_ERROR_URL="${LAST_DOWNLOAD_ERROR_URL:-}"
LAST_DOWNLOAD_ERROR_LOG="${LAST_DOWNLOAD_ERROR_LOG:-}"
LAST_DOWNLOAD_ERROR_MESSAGE="${LAST_DOWNLOAD_ERROR_MESSAGE:-}"
LAST_DOWNLOAD_ERROR_RC="${LAST_DOWNLOAD_ERROR_RC:-}"

cleanup_tracked_download_log() {
  local log_path="${1:-}"

  if [[ "$log_path" == /tmp/isoforge-download.*.log ]] && [[ -f "$log_path" ]]; then
    rm -f "$log_path"
  fi
}

clear_last_download_error() {
  cleanup_tracked_download_log "${LAST_DOWNLOAD_ERROR_LOG:-}"
  LAST_DOWNLOAD_ERROR_TIME=""
  LAST_DOWNLOAD_ERROR_OPERATION=""
  LAST_DOWNLOAD_ERROR_SOURCE=""
  LAST_DOWNLOAD_ERROR_URL=""
  LAST_DOWNLOAD_ERROR_LOG=""
  LAST_DOWNLOAD_ERROR_MESSAGE=""
  LAST_DOWNLOAD_ERROR_RC=""
}

record_last_download_error() {
  local previous_log="${LAST_DOWNLOAD_ERROR_LOG:-}"
  local next_log="${5:-}"

  if [[ -n "$previous_log" && "$previous_log" != "$next_log" ]]; then
    cleanup_tracked_download_log "$previous_log"
  fi
  LAST_DOWNLOAD_ERROR_TIME="${1:-}"
  LAST_DOWNLOAD_ERROR_OPERATION="${2:-}"
  LAST_DOWNLOAD_ERROR_SOURCE="${3:-}"
  LAST_DOWNLOAD_ERROR_URL="${4:-}"
  LAST_DOWNLOAD_ERROR_LOG="${5:-}"
  LAST_DOWNLOAD_ERROR_MESSAGE="${6:-}"
  LAST_DOWNLOAD_ERROR_RC="${7:-}"
}

has_last_download_error() {
  [[ -n "${LAST_DOWNLOAD_ERROR_TIME:-}" ]]
}

last_download_error_summary() {
  if ! has_last_download_error; then
    return 1
  fi

  printf 'Last download error: [%s] %s %s\n' \
    "$LAST_DOWNLOAD_ERROR_TIME" \
    "${LAST_DOWNLOAD_ERROR_OPERATION:-download}" \
    "${LAST_DOWNLOAD_ERROR_SOURCE:-unknown source}"
  printf 'Reason: %s\n' "${LAST_DOWNLOAD_ERROR_MESSAGE:-unknown error}"
  printf 'URL: %s\n' "${LAST_DOWNLOAD_ERROR_URL:-unknown}"
  printf 'Log: %s\n' "${LAST_DOWNLOAD_ERROR_LOG:-unavailable}"
}

show_last_download_error_dialog() {
  has_last_download_error || return 1
  dialog --title "Download Error" --msgbox "$(last_download_error_summary)" 14 76
}

print_last_download_error_cli() {
  has_last_download_error || return 1
  printf '%s\n' "$(last_download_error_summary)"
}

download_file_with_error_tracking() {
  local url="$1"
  local output="${2:-}"
  local operation="${3:-download}"
  local source_ref="${4:-$url}"
  local function_errexit_was_on=0

  if [[ $- == *e* ]]; then
    function_errexit_was_on=1
  fi

  if [[ -z "$output" ]]; then
    output=$(basename "$url")
    if [[ "$output" != *.* ]]; then
      output=$(echo "$url" | sed -E 's|.*/([^/]+\.[^/]+)(/.*)?$|\1|')
    fi
  fi

  local dir tmpfile log_file mkdir_err
  dir=$(dirname -- "$output")
  if [[ -n "$dir" && "$dir" != "." ]] && [[ ! -d "$dir" ]]; then
    if ! mkdir_err=$(mkdir -p "$dir" 2>&1); then
      log_file=$(mktemp "/tmp/isoforge-download.XXXXXXXX.log")
      {
        printf 'Failed to create output directory "%s" for download.\n' "$dir"
        printf 'mkdir output:\n%s\n' "$mkdir_err"
      } >"$log_file"
      record_last_download_error \
        "$(date '+%Y-%m-%d %H:%M:%S %Z')" \
        "$operation" \
        "$source_ref" \
        "$url" \
        "$log_file" \
        "Failed to create output directory \"$dir\"." \
        "1"
      return 1
    fi
  fi
  tmpfile="${output}.part"
  log_file=$(mktemp "/tmp/isoforge-download.XXXXXXXX.log")
  rm -f "$tmpfile"

  local tool
  if command -v curl >/dev/null 2>&1; then
    tool="curl"
  elif command -v wget >/dev/null 2>&1; then
    tool="wget"
  else
    printf 'Neither curl nor wget is installed.\n' >"$log_file"
    record_last_download_error \
      "$(date '+%Y-%m-%d %H:%M:%S %Z')" \
      "$operation" \
      "$source_ref" \
      "$url" \
      "$log_file" \
      "Neither curl nor wget is installed." \
      "127"
    return 127
  fi

  local -a cmd
  if [[ "$tool" == "curl" ]]; then
    cmd=(curl -L --fail -sS -o "$tmpfile" "$url")
  else
    cmd=(wget -nv -O "$tmpfile" "$url")
  fi

  "${cmd[@]}" >"$log_file" 2>&1 &
  local pid=$!

  if command -v dialog >/dev/null 2>&1; then
    local pipefail_was_on=0 dialog_errexit_was_on=0 dlg_rc
    if shopt -qo pipefail; then
      pipefail_was_on=1
      set +o pipefail
    fi
    if [[ $- == *e* ]]; then
      dialog_errexit_was_on=1
      set +e
    fi
    (
      local percent=0 cur_bytes
      while kill -0 "$pid" >/dev/null 2>&1; do
        cur_bytes=0
        if [[ -f "$tmpfile" ]]; then
          cur_bytes=$(wc -c <"$tmpfile" 2>/dev/null || echo 0)
        fi
        percent=$(( (percent + 3) % 100 ))
        printf 'XXX\n%d\n' "$percent"
        printf 'Downloading: %s\n' "$(basename -- "$output")"
        printf 'Downloaded: %s bytes\n' "$cur_bytes"
        printf 'XXX\n'
        sleep 1
      done
      printf 'XXX\n100\nFinalizing...\nXXX\n'
    ) | dialog --no-shadow --title "Downloading" --gauge "Preparing download..." 12 72 0
    dlg_rc=$?
    if (( dialog_errexit_was_on )); then
      set -e
    fi
    if (( pipefail_was_on )); then
      set -o pipefail
    fi
    if (( dlg_rc != 0 )); then
      if kill -0 "$pid" >/dev/null 2>&1; then
        kill "$pid" 2>/dev/null || true
      fi
      wait "$pid" 2>/dev/null || true
      rm -f "$tmpfile"
      local err_preview="Download canceled by user via dialog."
      printf '%s\n' "$err_preview" >"$log_file"
      record_last_download_error \
        "$(date '+%Y-%m-%d %H:%M:%S %Z')" \
        "$operation" \
        "$source_ref" \
        "$url" \
        "$log_file" \
        "$err_preview" \
        "$dlg_rc"
      if command -v dialog >/dev/null 2>&1; then
        show_last_download_error_dialog || true
      fi
      return "$dlg_rc"
    fi
  fi

  local rc
  if (( function_errexit_was_on )); then
    set +e
  fi
  wait "$pid"
  rc=$?
  if (( function_errexit_was_on )); then
    set -e
  fi
  if (( rc == 0 )); then
    local mv_rc rm_rc op_rc err_preview
    if (( function_errexit_was_on )); then
      set +e
    fi
    mv -f "$tmpfile" "$output"
    mv_rc=$?
    rm_rc=0
    if (( mv_rc == 0 )); then
      rm -f "$log_file"
      rm_rc=$?
    fi
    if (( function_errexit_was_on )); then
      set -e
    fi
    if (( mv_rc == 0 && rm_rc == 0 )); then
      return 0
    fi
    op_rc=$mv_rc
    if (( op_rc == 0 )); then
      op_rc=$rm_rc
    fi
    if (( mv_rc != 0 )); then
      rm -f "$tmpfile"
    fi
    if (( mv_rc != 0 )); then
      printf '\nFailed to move downloaded file into place.\n' >>"$log_file"
    fi
    if (( rm_rc != 0 )); then
      printf '\nFailed to remove temporary download log.\n' >>"$log_file"
    fi
    if [[ -s "$log_file" ]]; then
      err_preview=$(tail -n 20 "$log_file")
    else
      err_preview="No additional error output captured."
    fi
    record_last_download_error \
      "$(date '+%Y-%m-%d %H:%M:%S %Z')" \
      "$operation" \
      "$source_ref" \
      "$url" \
      "$log_file" \
      "$err_preview" \
      "$op_rc"
    if command -v dialog >/dev/null 2>&1; then
      show_last_download_error_dialog || true
    fi
    return "$op_rc"
  fi

  rm -f "$tmpfile"
  local err_preview
  if [[ -s "$log_file" ]]; then
    err_preview=$(tail -n 20 "$log_file")
  else
    err_preview="No additional error output captured."
  fi
  record_last_download_error \
    "$(date '+%Y-%m-%d %H:%M:%S %Z')" \
    "$operation" \
    "$source_ref" \
    "$url" \
    "$log_file" \
    "$err_preview" \
    "$rc"
  if command -v dialog >/dev/null 2>&1; then
    show_last_download_error_dialog || true
  fi
  return "$rc"
}
