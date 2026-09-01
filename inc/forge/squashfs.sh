#!/usr/bin/env bash
# Writing the customized root filesystem back into the image tree.

FORGE_SQUASHFS_COMP="${FORGE_SQUASHFS_COMP:-zstd}"
FORGE_SQUASHFS_LEVEL="${FORGE_SQUASHFS_LEVEL:-19}"

forge_mksquashfs() {
  local src="$1" dest="$2"
  local -a args=(-noappend -b 1M -comp "$FORGE_SQUASHFS_COMP" -wildcards -e 'boot/grub')

  # -Xcompression-level is only meaningful for the algorithms that take one.
  case "$FORGE_SQUASHFS_COMP" in
    zstd|xz) args+=(-Xcompression-level "$FORGE_SQUASHFS_LEVEL") ;;
  esac

  rm -f "$dest"
  log_info "Compressing the root filesystem with $FORGE_SQUASHFS_COMP (this is the slow part)"
  if ! mksquashfs "$src" "$dest" "${args[@]}" >/dev/null; then
    log_error "mksquashfs failed writing $dest"
    return 1
  fi
}

# casper reads filesystem.size to size its progress bar, and the installer
# reads the manifest to decide what to remove for a minimal install. Both are
# stale the moment packages change.
forge_write_manifest() {
  local rootfs="$1" casper="$2" stem="$3"

  local size
  size=$(du -sx --block-size=1 "$rootfs" | cut -f1)
  printf '%s' "$size" >"$casper/${stem}.size"

  if [[ -f "$casper/${stem}.manifest" ]] || [[ -f "$casper/filesystem.manifest" ]]; then
    log_info "Regenerating the package manifest"
    forge_in_chroot "dpkg-query -W --showformat='\${Package} \${Version}\n'" >"$casper/${stem}.manifest" 2>/dev/null || {
      log_warn "Could not regenerate ${stem}.manifest; leaving the previous one."
    }
  fi
}

forge_repack_single() {
  local rootfs="$1" iso_dir="$2"
  local casper="$iso_dir/casper"

  forge_write_manifest "$rootfs" "$casper" "filesystem"
  forge_mksquashfs "$rootfs" "$casper/filesystem.squashfs" || return $?
}

# The overlay upperdir holds exactly what the build changed, including
# overlayfs whiteouts for deletions, which mksquashfs preserves as the
# character devices casper's overlay understands.
forge_repack_layered() {
  local work="$1" iso_dir="$2"
  local casper="$iso_dir/casper"
  local upper="$work/upper"
  local stem name

  stem="$(basename "$FORGE_TOP_LAYER" .squashfs)"
  name="${stem}.isoforge"

  if [[ -z "$(ls -A "$upper" 2>/dev/null)" ]]; then
    log_warn "The build changed nothing; not adding an empty layer."
    return 0
  fi

  log_info "Writing the customization as a new layer: ${name}.squashfs"
  forge_mksquashfs "$upper" "$casper/${name}.squashfs" || return $?

  local size
  size=$(du -sx --block-size=1 "$upper" | cut -f1)
  printf '%s' "$size" >"$casper/${name}.size"

  forge_register_layer "$iso_dir" "$name" || return $?
}

# install-sources.yaml is what the installer reads to find the filesystem it
# should lay down. A new layer that is not registered there is carried on the
# ISO and ignored.
forge_register_layer() {
  local iso_dir="$1" name="$2"
  local sources="$iso_dir/casper/install-sources.yaml"

  if [[ ! -f "$sources" ]]; then
    log_warn "No casper/install-sources.yaml; the installer may not see ${name}.squashfs."
    return 0
  fi

  log_info "Registering the new layer in install-sources.yaml"
  local from
  from="$(basename "$FORGE_TOP_LAYER" .squashfs)"
  cp -a "$sources" "$sources.isoforge-orig"
  if ! forge_yaml_repoint_source "$sources" "$from" "$name"; then
    # Leave the original in place rather than writing something the installer
    # might choke on, and say exactly what needs doing by hand.
    mv -f "$sources.isoforge-orig" "$sources"
    log_warn "Could not repoint install-sources.yaml from '$from' to '$name'."
    log_warn "Edit it by hand before installing from this image."
    return 0
  fi
  rm -f "$sources.isoforge-orig"
}

forge_repack() {
  local work="$1" rootfs="$2" iso_dir="$3"

  case "$FORGE_LAYOUT" in
    single)  forge_repack_single "$rootfs" "$iso_dir" ;;
    layered) forge_repack_layered "$work" "$iso_dir" ;;
    *)       log_error "Unknown layout '$FORGE_LAYOUT'"; return 2 ;;
  esac
}
