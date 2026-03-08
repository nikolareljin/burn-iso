#!/usr/bin/env bash
# SCRIPT: test.sh
# DESCRIPTION: Run canonical repository validation checks.
# USAGE: ./test [-h] [--no-shellcheck]
# PARAMETERS:
# -h                : show help
# --no-shellcheck   : skip shellcheck validation
# EXAMPLE: ./test
set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    if [[ "$SCRIPT_SOURCE" != /* ]]; then
        SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
    fi
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SELF_CMD="./$(basename "$0")"

usage() {
    cat <<USAGE
Run canonical validation checks.

Usage: ${SELF_CMD} [-h] [--no-shellcheck]

Options:
  -h               Show help
  --no-shellcheck  Skip shellcheck checks
USAGE
}

run_shellcheck=true
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --no-shellcheck) run_shellcheck=false ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

cd "$ROOT_DIR"

./scripts/build.sh

if command -v jq >/dev/null 2>&1; then
    jq -e '.distros and (.distros | type == "array")' config.json >/dev/null
else
    echo "warning: jq not available; skipping config schema check" >&2
fi

if $run_shellcheck; then
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "shellcheck not found. Install shellcheck or run ${SELF_CMD} --no-shellcheck" >&2
        exit 1
    fi
    mapfile -t project_shell_files < <(find . \
        -path './.git' -prune -o \
        -path './scripts/script-helpers' -prune -o \
        -path './dist' -prune -o \
        -type f -name '*.sh' -print | sort)
    shellcheck -x -e SC1091 "${project_shell_files[@]}"
fi

echo "All test checks passed."
