#!/usr/bin/env bash
# SCRIPT: update-submodules.sh
# DESCRIPTION: Sync and initialize configured git submodules.
# USAGE: ./scripts/update-submodules.sh [-h] [-r]
# PARAMETERS:
# -h                : show help
# -r                : update submodules to latest remote commit on configured branch
# EXAMPLE: ./scripts/update-submodules.sh -r
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

usage() {
    cat <<'USAGE'
Sync and initialize configured git submodules.

Usage: ./scripts/update-submodules.sh [-h] [-r]

Options:
  -h    Show help
  -r    Refresh submodules from remote tracking branches
USAGE
}

update_remote=false
while getopts ":hr" opt; do
    case "${opt}" in
        h) usage; exit 0 ;;
        r) update_remote=true ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
done

if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: $ROOT_DIR is not a git worktree" >&2
    exit 1
fi

if [[ ! -f "$ROOT_DIR/.gitmodules" ]]; then
    echo "No .gitmodules found; nothing to update."
    exit 0
fi

git_config_output="$(git -C "$ROOT_DIR" config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>&1)" || {
    git_config_status=$?
    if [[ "$git_config_status" -eq 1 ]]; then
        echo "No configured submodules found in .gitmodules."
        exit 0
    fi
    echo "error: failed to read submodule paths from .gitmodules:" >&2
    echo "$git_config_output" >&2
    exit "$git_config_status"
}
mapfile -t configured_paths < <(printf '%s\n' "$git_config_output" | awk '{print $2}')
if [[ "${#configured_paths[@]}" -eq 0 ]]; then
    echo "No configured submodules found in .gitmodules."
    exit 0
fi

mapfile -t gitlink_paths < <(git -C "$ROOT_DIR" ls-files -s | awk '$1=="160000"{print $4}')

for path in "${configured_paths[@]}"; do
    [[ -n "$path" ]] || continue
    found=0
    for gitlink_path in "${gitlink_paths[@]}"; do
        if [[ "$path" == "$gitlink_path" ]]; then
            found=1
            break
        fi
    done
    if [[ "$found" -eq 0 ]]; then
        echo "warning: skipping stale .gitmodules entry not present in index: $path" >&2
        continue
    fi
    git -C "$ROOT_DIR" submodule sync --recursive -- "$path"
    if $update_remote; then
        git -C "$ROOT_DIR" submodule update --init --recursive --remote -- "$path"
    else
        git -C "$ROOT_DIR" submodule update --init --recursive -- "$path"
    fi
done

echo "Submodules updated."
