#!/usr/bin/env bash
# The NikOS recipe, and the guard that keeps its tag list honest.
#
# The real proof that NikOS builds is .github/workflows/nikos-iso.yml, which
# takes about an hour. These are the checks worth having on every pull request:
# they catch a recipe that has drifted from what the playbook actually offers,
# which is the failure that would otherwise cost that hour to discover.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$REPO_ROOT/scripts/script-helpers}"

if [[ ! -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  echo "script-helpers not initialized; run ./update" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging
for m in yaml recipe fetch; do
  # shellcheck source=/dev/null
  source "$REPO_ROOT/inc/forge/$m.sh"
done

CONFIG_FILE="$REPO_ROOT/config.json"
RECIPE="$REPO_ROOT/recipes/nikos.yml"

pass=0
fail=0
ok()  { printf 'ok   - %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL - %s\n' "$1"; fail=$((fail + 1)); }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }

# --- the recipe itself ------------------------------------------------------
recipe_load "$RECIPE" >/dev/null 2>&1 || { echo "recipes/nikos.yml does not load" >&2; exit 1; }
ok "recipes/nikos.yml loads and validates"

check "it builds on a Xubuntu base" \
  "$(recipe_get '.base.catalog_id')" "Xubuntu_24_04_4_desktop_amd64"

if [[ -n "$(forge_catalog_url "$(recipe_get '.base.catalog_id')")" ]]; then
  ok "that base resolves to a URL in config.json"
else
  bad "that base resolves to a URL in config.json"
fi

check "the output is named for NikOS"   "$(recipe_get '.output.name')"      "nikos-24.04-amd64"
check "the volume id is the recipe's"   "$(recipe_get '.output.volume_id')" "NIKOS_2404"

# The whole point of the NikOS path: the playbook's per-user work has to land
# somewhere every account created by the installer inherits.
check "per-user configuration targets /etc/skel" \
  "$(recipe_get '.ansible.skel_home')" "/etc/skel"

check "it provisions from the NikOS repository" \
  "$(recipe_get '.ansible.repo')" "https://github.com/nikolareljin/nikos"

if [[ "$(recipe_get '.ansible.ref // ""')" != "" ]]; then
  ok "the playbook is pinned to a ref rather than tracking a branch"
else
  bad "the playbook is pinned to a ref rather than tracking a branch"
fi

# github-setup is a role with no `tags:` key, so naming it in skip_tags does
# nothing at all. It was in this recipe once, and the build silently included
# it. That specific mistake stays caught.
if recipe_list '.ansible.skip_tags' | grep -qx "github-setup"; then
  bad "skip_tags does not name the untagged github-setup role"
else
  ok "skip_tags does not name the untagged github-setup role"
fi

mapfile -t skips < <(recipe_list '.ansible.skip_tags')
if ((${#skips[@]})); then
  ok "the heavy optional roles are skipped (${#skips[@]} tags)"
else
  bad "the heavy optional roles are skipped"
fi
# Ollama models are gigabytes and belong on the installed machine, not in an ISO.
if printf '%s\n' "${skips[@]}" | grep -qx "ai-local"; then
  ok "the local AI stack is left out of the image"
else
  bad "the local AI stack is left out of the image"
fi

# The first real build failed here: `code --install-extension` refuses to run as
# root, and extensions install into a user's own ~/.vscode anyway, so there is
# no build-time place to put them.
check "VS Code extensions are left to first login" \
  "$(recipe_get '.ansible.extra_vars.nikos_vscode_extensions | length')" "0"
check "AI VS Code extensions are left to first login" \
  "$(recipe_get '.ansible.extra_vars.nikos_vscode_ai_extensions | length')" "0"

# A list has to reach ansible as a list. `-e key=value` always makes a string,
# and a role concatenating that with another list fails on the type.
check "extra_vars keeps a list a list" \
  "$(recipe_get '.ansible.extra_vars.nikos_vscode_extensions | type')" "array"
check "extra_vars keeps a string a string" \
  "$(recipe_get '.ansible.extra_vars.nikos_desktop_flavor | type')" "string"

# --- the tag guard ----------------------------------------------------------
# shellcheck source=/dev/null
source "$REPO_ROOT/inc/forge/chroot.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/inc/forge/ansible.sh"

# Stand in for the chroot with the shape ansible-playbook --list-tags prints.
forge_in_chroot() {
  case "${FAKE_TAGS_MODE:-normal}" in
    normal) printf 'play #1 (local): NikOS Setup\tTAGS: []\n      TASK TAGS: [ai-local, always, education, music, network]\n' ;;
    empty)  printf 'play #1 (local): NikOS Setup\n' ;;
    fail)   return 1 ;;
  esac
}

if forge_ansible_check_tags /opt/nikos site.yml inventory/local skip_tags ai-local network >/dev/null 2>&1; then
  ok "tags the playbook defines are accepted"
else
  bad "tags the playbook defines are accepted"
fi

if forge_ansible_check_tags /opt/nikos site.yml inventory/local skip_tags github-setup >/dev/null 2>&1; then
  bad "a skip_tag the playbook does not define is rejected"
else
  ok "a skip_tag the playbook does not define is rejected"
fi

if forge_ansible_check_tags /opt/nikos site.yml inventory/local tags nonexistent >/dev/null 2>&1; then
  bad "a tag the playbook does not define is rejected"
else
  ok "a tag the playbook does not define is rejected"
fi

if forge_ansible_check_tags /opt/nikos site.yml inventory/local skip_tags >/dev/null 2>&1; then
  ok "an empty tag list is accepted"
else
  bad "an empty tag list is accepted"
fi

# If the tags cannot be listed at all, that is not a reason to refuse to build.
FAKE_TAGS_MODE=fail
if forge_ansible_check_tags /opt/nikos site.yml inventory/local skip_tags anything >/dev/null 2>&1; then
  ok "an unreadable tag listing warns rather than failing the build"
else
  bad "an unreadable tag listing warns rather than failing the build"
fi
FAKE_TAGS_MODE=empty
if forge_ansible_check_tags /opt/nikos site.yml inventory/local skip_tags anything >/dev/null 2>&1; then
  ok "a playbook reporting no tags warns rather than failing the build"
else
  bad "a playbook reporting no tags warns rather than failing the build"
fi
FAKE_TAGS_MODE=normal

# --- the verifier ships and is runnable ------------------------------------
if [[ -x "$REPO_ROOT/scripts/verify-nikos-iso.sh" ]]; then
  ok "the ISO verifier is executable"
else
  bad "the ISO verifier is executable"
fi
if bash -n "$REPO_ROOT/scripts/verify-nikos-iso.sh" 2>/dev/null; then
  ok "the ISO verifier parses"
else
  bad "the ISO verifier parses"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
