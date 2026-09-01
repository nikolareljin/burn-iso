#!/usr/bin/env bash
# Layout detection, squashfs repacking and ISO packing, against a synthetic
# image a few hundred kilobytes in size.
#
# This exercises the real code on a real ISO rather than a mock: a full Ubuntu
# base is several gigabytes and needs root to chroot into, neither of which
# belongs in a pull-request check. The stages that need root (bind mounts,
# chroot, overlayfs) are skipped here and are covered by the documented manual
# build in docs/BUILD.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$REPO_ROOT/scripts/script-helpers}"

if [[ ! -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  echo "script-helpers not initialized; run ./update" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging file
for m in yaml recipe preflight fetch extract squashfs image verify; do
  # shellcheck source=/dev/null
  source "$REPO_ROOT/inc/forge/$m.sh"
done

pass=0
fail=0
ok()  { printf 'ok   - %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL - %s\n' "$1"; fail=$((fail + 1)); }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }

for t in xorriso mksquashfs unsquashfs; do
  if ! command -v "$t" >/dev/null 2>&1; then
    printf 'SKIP - %s is not installed; image tests need xorriso and squashfs-tools\n' "$t"
    exit 0
  fi
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- build a synthetic base image ------------------------------------------
make_base() {
  local layout="$1"
  local root="$TMP/$layout"
  rm -rf "$root"
  mkdir -p "$root/tree/casper" "$root/tree/.disk" "$root/rootfs/etc" "$root/rootfs/usr/bin"

  printf 'synthetic\n' >"$root/rootfs/etc/os-release"
  printf 'placeholder\n' >"$root/rootfs/usr/bin/true-ish"
  printf 'base image\n' >"$root/tree/.disk/info"
  printf 'nothing here\n' >"$root/tree/README.diskdefines"

  case "$layout" in
    single)
      mksquashfs "$root/rootfs" "$root/tree/casper/filesystem.squashfs" -noappend -quiet >/dev/null
      ;;
    layered)
      mkdir -p "$root/lower2"
      printf 'standard layer\n' >"$root/lower2/marker"
      mksquashfs "$root/rootfs" "$root/tree/casper/minimal.squashfs" -noappend -quiet >/dev/null
      mksquashfs "$root/lower2" "$root/tree/casper/minimal.standard.squashfs" -noappend -quiet >/dev/null
      cat >"$root/tree/casper/install-sources.yaml" <<'YAML'
- default: true
  description:
    en: Synthetic
  id: synthetic
  locale_support: none
  name:
    en: Synthetic
  path: minimal.standard
  type: fsimage-layered
YAML
      ;;
  esac

  ( cd "$root/tree" && find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 md5sum >md5sum.txt )
  xorriso -as mkisofs -V SYNTHETIC -o "$root/base.iso" "$root/tree" >/dev/null 2>&1
  printf '%s' "$root/base.iso"
}

# --- single layout ----------------------------------------------------------
base=$(make_base single)
[[ -f "$base" ]] && ok "a synthetic single-layout base image is produced" || bad "synthetic base image"

work="$TMP/work-single"
mkdir -p "$work"
if forge_extract_iso "$base" "$work/iso" >/dev/null 2>&1; then
  ok "the base image extracts"
else
  bad "the base image extracts"
fi
check "the extracted tree is writable" "$([[ -w "$work/iso/casper" ]] && echo yes || echo no)" "yes"

forge_detect_layout "$work/iso" >/dev/null 2>&1
check "a single squashfs is detected as 'single'" "$FORGE_LAYOUT" "single"
check "the top layer is filesystem.squashfs" "$(basename "$FORGE_TOP_LAYER")" "filesystem.squashfs"

if forge_prepare_root "$work" >/dev/null 2>&1; then
  ok "the root filesystem unpacks"
else
  bad "the root filesystem unpacks"
fi
check "unpacked content is present" "$(cat "$work/rootfs/etc/os-release" 2>/dev/null)" "synthetic"

# A change made to the unpacked tree has to survive the repack.
printf 'added by the build\n' >"$work/rootfs/etc/isoforge-marker"
if forge_mksquashfs "$work/rootfs" "$work/iso/casper/filesystem.squashfs" >/dev/null 2>&1; then
  ok "the root filesystem repacks"
else
  bad "the root filesystem repacks"
fi
unsquashfs -d "$work/verify" "$work/iso/casper/filesystem.squashfs" >/dev/null 2>&1 || true
check "the change survives the repack" "$(cat "$work/verify/etc/isoforge-marker" 2>/dev/null)" "added by the build"

# md5sum.txt is what the "check disc for defects" boot entry verifies; a stale
# one fails on every rebuilt image.
before=$(md5sum "$work/iso/md5sum.txt" | awk '{print $1}')
forge_finalize_tree "$work/iso" "REBUILT" "$base" >/dev/null 2>&1
after=$(md5sum "$work/iso/md5sum.txt" | awk '{print $1}')
if [[ "$before" != "$after" ]]; then ok "md5sum.txt is regenerated"; else bad "md5sum.txt is regenerated"; fi
check ".disk/info carries the new label" "$(cat "$work/iso/.disk/info")" "REBUILT"

out="$work/out.iso"
if forge_pack "$work/iso" "$base" "$out" "REBUILT" >/dev/null 2>&1; then
  ok "the tree packs back into an ISO"
else
  bad "the tree packs back into an ISO"
fi
if [[ -f "$out" ]] && is_valid_iso "$out"; then
  ok "the output is an ISO 9660 image"
else
  bad "the output is an ISO 9660 image"
fi
volid=$(xorriso -indev "$out" -pvd_info 2>&1 | sed -n "s/^Volume id *: *'\(.*\)'$/\1/p" | head -1)
check "the volume id is applied" "$volid" "REBUILT"

if forge_verify "$out" >/dev/null 2>&1; then ok "the built image verifies"; else bad "the built image verifies"; fi
check "a checksum file is written alongside" "$([[ -f "$out.sha256" ]] && echo yes || echo no)" "yes"

# --- layered layout ---------------------------------------------------------
base2=$(make_base layered)
work2="$TMP/work-layered"
mkdir -p "$work2"
forge_extract_iso "$base2" "$work2/iso" >/dev/null 2>&1
forge_detect_layout "$work2/iso" >/dev/null 2>&1
check "stacked squashfs is detected as 'layered'" "$FORGE_LAYOUT" "layered"
check "every layer is collected" "${#FORGE_LAYER_PATHS[@]}" "2"
check "the top layer is the longest-named one" "$(basename "$FORGE_TOP_LAYER")" "minimal.standard.squashfs"

# The new layer must be registered or the installer carries it and ignores it.
FORGE_TOP_LAYER="$work2/iso/casper/minimal.standard.squashfs"
if forge_register_layer "$work2/iso" "minimal.standard.isoforge" >/dev/null 2>&1; then
  ok "install-sources.yaml is repointed at the new layer"
else
  bad "install-sources.yaml is repointed at the new layer"
fi
check "the source now names the new layer" \
  "$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))[0]["path"])' "$work2/iso/casper/install-sources.yaml" 2>/dev/null)" \
  "minimal.standard.isoforge"

# A layered image whose install-sources.yaml cannot be repointed must fail the
# build: the installer would keep the original layer and drop everything added.
rm -f "$work2/iso/casper/install-sources.yaml"
if forge_register_layer "$work2/iso" "minimal.standard.isoforge" >/dev/null 2>&1; then
  bad "a missing install-sources.yaml fails the build"
else
  ok "a missing install-sources.yaml fails the build"
fi

cat >"$work2/iso/casper/install-sources.yaml" <<'YAML'
- id: unrelated
  path: something-else
YAML
if forge_register_layer "$work2/iso" "minimal.standard.isoforge" >/dev/null 2>&1; then
  bad "an install-sources.yaml that cannot be repointed fails the build"
else
  ok "an install-sources.yaml that cannot be repointed fails the build"
fi
check "the original install-sources.yaml is restored on failure" \
  "$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))[0]["path"])' "$work2/iso/casper/install-sources.yaml" 2>/dev/null)" \
  "something-else"

# --- architecture detection -------------------------------------------------
mkdir -p "$TMP/arch/.disk"
printf 'Xubuntu 24.04.4 LTS "Noble Numbat" - Release amd64 (20250101)\n' >"$TMP/arch/.disk/info"
check "the architecture is read from .disk/info" "$(forge_detect_arch "$TMP/arch" /tmp/whatever.iso)" "amd64"
rm -f "$TMP/arch/.disk/info"
check "the architecture falls back to the filename" "$(forge_detect_arch "$TMP/arch" /tmp/thing-arm64.iso)" "arm64"
check "an unknown architecture reads as empty" "$(forge_detect_arch "$TMP/arch" /tmp/mystery.iso)" ""

# --- a base that is not a live image ---------------------------------------
mkdir -p "$TMP/notlive/tree/random"
printf 'x\n' >"$TMP/notlive/tree/random/file"
xorriso -as mkisofs -o "$TMP/notlive/base.iso" "$TMP/notlive/tree" >/dev/null 2>&1
forge_extract_iso "$TMP/notlive/base.iso" "$TMP/notlive/iso" >/dev/null 2>&1
if forge_detect_layout "$TMP/notlive/iso" >/dev/null 2>&1; then
  bad "an image with no casper/ is rejected"
else
  ok "an image with no casper/ is rejected"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
