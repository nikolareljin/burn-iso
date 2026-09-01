#!/usr/bin/env bash
# Image metadata and packing the tree back into a bootable ISO.

# Boot flags are the usual reason a remastered image will not start: BIOS and
# UEFI need different El Torito entries, and modern Ubuntu images also carry an
# appended GPT partition holding the EFI system partition. Rather than guess at
# a set of -as mkisofs flags, ask xorriso to report the arguments that would
# reproduce the source image's boot setup, and reuse those verbatim. The report
# names the source ISO in its --interval: tokens, so the base image has to stay
# where it is until the pack finishes.
# 0 the base has a boot record and its arguments were captured
# 3 the base has no boot record at all, so there is nothing to reproduce
# 1 the base has a boot record but the arguments could not be read
forge_boot_args() {
  local base_iso="$1"
  local report

  # xorriso writes its banner and the arguments to the same stream, so the
  # arguments are the lines starting with a dash and the banner is the rest.
  report=$(xorriso -indev "$base_iso" -report_el_torito as_mkisofs 2>&1) || return 1

  if ! grep -q '^Boot record' <<<"$report"; then
    return 3
  fi

  local args
  # --modification-date would stamp the rebuilt image with the base image's
  # creation time, so it is dropped and the new image gets its own.
  args=$(grep '^-' <<<"$report" | grep -v '^--modification-date=')
  [[ -n "$args" ]] || return 1
  printf '%s' "$args"
}

forge_set_volume_id() {
  local iso_dir="$1" label="$2"
  [[ -n "$label" ]] || return 0

  # The boot menus name the volume they expect to find; if the label moves and
  # they do not, the live session drops to an initramfs prompt.
  local f
  for f in "$iso_dir/boot/grub/grub.cfg" "$iso_dir/isolinux/txt.cfg" "$iso_dir/boot/grub/loopback.cfg"; do
    [[ -f "$f" ]] || continue
    sed -i "s|\(iso-scan/filename=\|LABEL=\)[^ ]*|\1$label|g" "$f" 2>/dev/null || true
  done
}

forge_disk_info() {
  local iso_dir="$1" label="$2"
  [[ -n "$label" ]] || return 0
  mkdir -p "$iso_dir/.disk"
  printf '%s\n' "$label" >"$iso_dir/.disk/info"
}

# md5sum.txt is what the "Check disc for defects" boot entry verifies. Leaving
# the original there guarantees that check fails on every rebuilt image.
forge_checksums() {
  local iso_dir="$1"
  [[ -f "$iso_dir/md5sum.txt" ]] || return 0

  log_info "Regenerating md5sum.txt"
  ( cd "$iso_dir" && find . -type f \
      ! -name md5sum.txt \
      ! -path './isolinux/boot.cat' \
      -print0 | sort -z | xargs -0 md5sum >md5sum.txt.new ) || {
    log_error "Could not regenerate md5sum.txt"
    return 1
  }
  mv "$iso_dir/md5sum.txt.new" "$iso_dir/md5sum.txt"
}

forge_pack() {
  local iso_dir="$1" base_iso="$2" out="$3" label="$4"

  local reported rc=0
  reported=$(forge_boot_args "$base_iso") || rc=$?

  local -a args=()
  case "$rc" in
    0)
      # xorriso single-quotes paths in its report; xargs unquotes them the same
      # way, so a path with spaces survives the round trip.
      mapfile -t args < <(xargs -n1 <<<"$reported")
      ;;
    3)
      # Nothing to reproduce. A non-bootable base gives a non-bootable output,
      # which is consistent rather than an error.
      log_warn "The base image has no boot record; the rebuilt image will not be bootable."
      ;;
    *)
      log_error "xorriso could not report the boot setup of $base_iso."
      log_error "Without it the rebuilt image would very likely not boot, so this stops here."
      log_error "The base image must stay readable at that path for the whole build."
      return 1
      ;;
  esac

  # Replace the reported volume id with the recipe's, keeping everything else.
  local -a final=()
  local i skip_next=0
  for ((i = 0; i < ${#args[@]}; i++)); do
    if ((skip_next)); then
      skip_next=0
      continue
    fi
    case "${args[i]}" in
      -V|-volid)
        if [[ -n "$label" ]]; then
          final+=(-V "$label")
          skip_next=1
          continue
        fi
        ;;
      -o|-outdev)
        # The report should not carry an output, but drop one if it does.
        skip_next=1
        continue
        ;;
    esac
    final+=("${args[i]}")
  done
  if [[ -n "$label" ]] && ! printf '%s\n' "${final[@]}" | grep -qx -- '-V'; then
    final+=(-V "$label")
  fi

  log_info "Packing $(basename "$out")"
  rm -f "$out"
  if ! xorriso -as mkisofs "${final[@]}" -o "$out" "$iso_dir" >/dev/null 2>&1; then
    log_error "xorriso could not write $out"
    log_error "Arguments were: ${final[*]}"
    return 1
  fi
}

forge_finalize_tree() {
  local iso_dir="$1" label="$2"
  forge_disk_info "$iso_dir" "$label"
  forge_set_volume_id "$iso_dir" "$label"
  forge_checksums "$iso_dir" || return $?
}
