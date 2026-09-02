#!/usr/bin/env bash
# Checking the built image before anyone writes it to a drive.

forge_verify() {
  local out="$1"

  if [[ ! -f "$out" ]]; then
    log_error "No image was produced at $out"
    return 1
  fi

  if ! is_valid_iso "$out"; then
    log_error "$out is not an ISO 9660 image"
    return 1
  fi

  # A rebuilt image with no El Torito catalogue will not boot on anything, and
  # that is worth catching here rather than on the target machine.
  if ! xorriso -indev "$out" -report_el_torito plain >/dev/null 2>&1; then
    log_warn "Could not read a boot record from $out; it may not be bootable."
  fi

  local size sha
  size=$(du -h "$out" | cut -f1)
  sha=$(sha256sum "$out" | awk '{print $1}')
  printf '%s  %s\n' "$sha" "$(basename "$out")" >"$out.sha256"

  log_info "Built $out ($size)"
  log_info "sha256 $sha"
}

# An optional boot test. It proves the firmware hands off to the bootloader,
# which is where a bad remaster usually fails; it does not prove the installer
# runs to completion.
forge_smoke_test() {
  local out="$1"
  local seconds="${2:-45}"

  if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    log_warn "qemu-system-x86_64 is not installed; skipping the smoke test."
    return 0
  fi

  log_info "Booting the image under QEMU for ${seconds}s"
  local serial
  serial=$(mktemp /tmp/isoforge-smoke.XXXXXXXX.log)

  timeout "$seconds" qemu-system-x86_64 \
    -m 2048 -nographic -serial "file:$serial" \
    -drive "file=$out,media=cdrom,readonly=on" \
    -boot d >/dev/null 2>&1 || true

  if [[ -s "$serial" ]]; then
    log_info "The image produced boot output:"
    head -20 "$serial" >&2
    rm -f "$serial"
    return 0
  fi

  rm -f "$serial"
  log_warn "No boot output within ${seconds}s. That can mean a graphics-only"
  log_warn "bootloader rather than a broken image; check it by hand before trusting it."
  return 0
}
