#!/usr/bin/env bash
# Reading and editing YAML without adding a hard dependency on a binary that
# distributions do not ship.
#
# `yq` is ambiguous: the `yq` in the Debian and Ubuntu archives is the Python
# jq wrapper, while `-o=json` belongs to the unrelated Go implementation, so a
# recipe that parses on one machine fails on the next. PyYAML has one meaning
# wherever it is packaged, and rides on a python3 the build already needs, so
# it is the primary path and the Go yq is only a fallback. The package name
# does vary: python3-yaml on Debian and Ubuntu, python3dist(pyyaml) as the RPM
# virtual provide, python3-PyYAML on openSUSE.

forge_yaml_backend() {
  if python3 -c 'import yaml' >/dev/null 2>&1; then
    printf 'python'
  elif yq --version 2>&1 | grep -qi 'mikefarah'; then
    printf 'yq'
  else
    printf 'none'
  fi
}

forge_yaml_require() {
  local backend
  backend=$(forge_yaml_backend)
  if [[ "$backend" == "none" ]]; then
    log_error "Reading a recipe needs PyYAML (python3-yaml on Debian and Ubuntu, python3dist(pyyaml) on RPM distros)."
    log_error "The Go yq (github.com/mikefarah/yq) also works; the yq in the distribution archives does not."
    return 2
  fi
  printf '%s' "$backend"
}

forge_yaml_to_json() {
  local path="$1"
  local backend
  backend=$(forge_yaml_require) || return $?

  case "$backend" in
    python)
      python3 - "$path" <<'PY'
import json, sys, yaml
try:
    with open(sys.argv[1]) as fh:
        data = yaml.safe_load(fh)
except yaml.YAMLError as exc:
    sys.stderr.write("%s\n" % exc)
    sys.exit(2)
json.dump({} if data is None else data, sys.stdout)
PY
      ;;
    yq)
      yq -o=json '.' "$path"
      ;;
  esac
}

# Repoint the layered install source at a new squashfs stem. Edited through a
# YAML parser rather than sed so an installer never sees a file this mangled.
forge_yaml_repoint_source() {
  local path="$1" from="$2" to="$3"
  local backend
  backend=$(forge_yaml_require) || return $?
  if [[ "$backend" != "python" ]]; then
    # Reading a recipe works with either backend; rewriting install-sources.yaml
    # in place is only implemented for PyYAML. Say that, rather than letting the
    # caller report it as a layout problem.
    log_error "Editing install-sources.yaml needs PyYAML, and only the Go yq is available."
    log_error "On Debian and Ubuntu: apt-get install python3-yaml"
    return 2
  fi

  python3 - "$path" "$from" "$to" <<'PY'
import sys, yaml

path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as fh:
    doc = yaml.safe_load(fh)

changed = 0

SUFFIX = ".squashfs"


def stem_of(value):
    return value[:-len(SUFFIX)] if value.endswith(SUFFIX) else value


def walk(node):
    global changed
    if isinstance(node, dict):
        for key, value in node.items():
            # `path` carries the file name, extension included, and some
            # releases repeat the bare stem in `id`. Compare on stems and write
            # back in whichever form was already there.
            if key == "path" and isinstance(value, str) and stem_of(value) == stem_of(old):
                node[key] = new + SUFFIX if value.endswith(SUFFIX) else new
                changed += 1
            elif key == "id" and isinstance(value, str) and stem_of(value) == stem_of(old):
                node[key] = new
                changed += 1
            else:
                walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)

walk(doc)
if not changed:
    sys.exit(3)

with open(path, "w") as fh:
    yaml.safe_dump(doc, fh, default_flow_style=False, sort_keys=False)
PY
}

# Replace every occurrence of one string with another, literally. Base volume
# ids routinely carry dots and spaces ("Ubuntu 24.04.3 LTS amd64"), which as a
# sed pattern would match text the label does not, and any delimiter appearing
# in the label would end the expression outright.
forge_replace_literal() {
  local path="$1" old="$2" new="$3"
  [[ -f "$path" && -n "$old" ]] || return 0

  python3 - "$path" "$old" "$new" <<'PYEOF'
import sys

path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8", errors="surrogateescape") as fh:
    text = fh.read()
if old in text:
    with open(path, "w", encoding="utf-8", errors="surrogateescape") as fh:
        fh.write(text.replace(old, new))
PYEOF
}

# The stem install-sources.yaml points its layered source at. On Ubuntu that is
# the installed system's top layer, which is not the topmost squashfs on the
# image: minimal.standard.live sits above it and exists only for the live
# session.
forge_yaml_install_source_stem() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  [[ "$(forge_yaml_backend)" == "python" ]] || return 1

  python3 - "$path" <<'PYEOF'
import sys, yaml

with open(sys.argv[1]) as fh:
    doc = yaml.safe_load(fh)

found = []

def walk(node):
    if isinstance(node, dict):
        # Match on having a `path`, not on `type`. The type string has changed
        # between releases (fsimage, fsimage-layered), and a source without one
        # is still the source.
        if isinstance(node.get("path"), str) and node["path"]:
            found.append((node.get("default") is True, node["path"]))
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)

walk(doc)
if not found:
    sys.exit(3)
# Prefer the entry marked default, else the first one.
found.sort(key=lambda pair: not pair[0])
# Ubuntu writes the file name, extension and all: `path: minimal.standard.squashfs`.
# Everything downstream works in stems, so strip it.
path = found[0][1]
print(path[:-len(".squashfs")] if path.endswith(".squashfs") else path)
PYEOF
}
