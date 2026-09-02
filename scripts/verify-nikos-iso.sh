#!/usr/bin/env bash
# Assert that a built image really is NikOS, and not a stock Xubuntu that
# happened to survive the pipeline.
#
#   scripts/verify-nikos-iso.sh path/to/nikos-24.04-amd64.iso
#
# Checks the image itself (bootable, labelled, checksummed) and then the root
# filesystem inside it (the NikOS CLI, its Plymouth theme, its desktop package
# set, and the /etc/skel handoff that makes an installed account inherit the
# desktop). Everything here reads the artifact; nothing trusts the build log.
set -euo pipefail

ISO="${1:-}"
if [[ -z "$ISO" || ! -f "$ISO" ]]; then
  echo "usage: $0 <iso>" >&2
  exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
ok()   { printf 'ok   - %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf 'FAIL - %s\n' "$1"; fail=$((fail + 1)); }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }
have()  { if [[ -e "$2" ]]; then ok "$1"; else bad "$1 (missing: ${2#"$WORK/root"})"; fi; }

echo "== image =="
size_mb=$(( $(stat -c%s "$ISO") / 1024 / 1024 ))
if (( size_mb > 1500 )); then
  ok "image is ${size_mb} MB, in the range a desktop image should be"
else
  bad "image is only ${size_mb} MB; a Xubuntu-derived desktop image should be well over 1500 MB"
fi

if file "$ISO" | grep -q "ISO 9660"; then ok "image is ISO 9660"; else bad "image is ISO 9660"; fi

# A remaster that loses its boot record produces a file that mounts fine and
# boots nothing, which is the failure this whole exercise is meant to prevent.
if xorriso -indev "$ISO" -report_el_torito plain 2>&1 | grep -q "^Boot record"; then
  ok "image carries an El Torito boot record"
else
  bad "image carries an El Torito boot record"
fi

volid=$(xorriso -indev "$ISO" -pvd_info 2>&1 | sed -n "s/^Volume id *: *'\(.*\)'$/\1/p" | head -1)
check "volume id is the recipe's" "$volid" "NIKOS_2404"

echo
echo "== contents =="
xorriso -osirrox on -indev "$ISO" -extract / "$WORK/iso" >/dev/null 2>&1
chmod -R u+w "$WORK/iso" 2>/dev/null || true

have "casper/ is present" "$WORK/iso/casper"
check ".disk/info names the build" "$(cat "$WORK/iso/.disk/info" 2>/dev/null)" "NIKOS_2404"

squash=""
for candidate in "$WORK/iso/casper/filesystem.squashfs" "$WORK"/iso/casper/*.squashfs; do
  [[ -f "$candidate" ]] && { squash="$candidate"; break; }
done
if [[ -z "$squash" ]]; then
  bad "a squashfs is present in casper/"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  exit 1
fi
ok "root filesystem found: $(basename "$squash")"

manifest="${squash%.squashfs}.manifest"
[[ -f "$manifest" ]] || manifest="$WORK/iso/casper/filesystem.manifest"
if [[ -f "$manifest" ]]; then
  ok "a package manifest ships beside it"
  for pkg in xubuntu-desktop-minimal lightdm; do
    if grep -q "^$pkg " "$manifest"; then
      ok "manifest lists $pkg"
    else
      bad "manifest lists $pkg"
    fi
  done
else
  bad "a package manifest ships beside it"
fi

echo
echo "== NikOS inside the root filesystem =="
# -no-xattrs so this works unprivileged; ownership is irrelevant to what is
# being asserted here.
unsquashfs -no-xattrs -d "$WORK/root" "$squash" >/dev/null 2>&1 || \
  sudo unsquashfs -d "$WORK/root" "$squash" >/dev/null 2>&1

if [[ ! -d "$WORK/root" ]]; then
  bad "the root filesystem unpacks"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  exit 1
fi
ok "the root filesystem unpacks"

# site.yml's post_tasks install the CLI here. Its presence is the single
# clearest signal that the playbook ran to completion rather than dying midway.
have "the nikos CLI is installed" "$WORK/root/usr/local/bin/nikos"

# The theming role copies the pre-rendered boot chrome into place.
have "the NikOS Plymouth theme is installed" "$WORK/root/usr/share/plymouth/themes/nikos"

# The desktop role's package set.
have "the Xfce session is present" "$WORK/root/usr/bin/xfce4-session"
have "LightDM is present" "$WORK/root/usr/sbin/lightdm"

# The reason skel_home exists: an account created by the installer has to come
# out looking like NikOS, and /etc/skel is what it is seeded from.
if [[ -d "$WORK/root/etc/skel" ]] && [[ -n "$(find "$WORK/root/etc/skel" -mindepth 1 -maxdepth 2 -name 'xfce4' -o -mindepth 1 -maxdepth 2 -name '.config' 2>/dev/null)" ]]; then
  ok "/etc/skel carries desktop configuration for new accounts"
else
  bad "/etc/skel carries desktop configuration for new accounts"
fi

# The build's own cleanup, verified on the artifact rather than trusted.
if [[ ! -s "$WORK/root/etc/machine-id" ]]; then
  ok "/etc/machine-id is empty, so installs do not share an identity"
else
  bad "/etc/machine-id is empty, so installs do not share an identity"
fi

if [[ -e "$WORK/root/usr/sbin/policy-rc.d" ]]; then
  bad "the build's policy-rc.d was removed"
else
  ok "the build's policy-rc.d was removed"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
