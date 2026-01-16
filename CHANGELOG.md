# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning when applicable.

## 2026-01-09

### Breaking
- Renamed the primary CLI to `isoforge`; the `etcher` entrypoint is removed.
- Installable packages now provide `/usr/bin/isoforge` and `/usr/share/isoforge/config.json`.

### Packaging
- Added Debian, PPA, and RPM packaging support with CI workflows.

## 2025-11-07

- Created this changelog and summarized recent work.

## 2025-11-06

### UX and Menus
- Grouped selection UI for downloads and Etcher with clear category headers:
  Desktop / Linux; SBC — Raspberry Pi; SBC — Armbian / TV Box; Android / Tablet; Utilities / Repair; Surface / Xbox.
- Headers are non-selectable: ignored in multi-select, and re-prompted in single-select if chosen.

### Distros
- Expanded curated list in `config.json`:
  - Raspberry Pi: Raspberry Pi OS (Bookworm) Lite (arm64/armhf) and Ubuntu preinstalled server for RPi (arm64).
  - Armbian for Orange Pi 5/3, Banana Pi/M2+ (redirects to latest), and community TV box builds (Amlogic S905X).
  - Android-based OSes: Android-x86 9.0-r2, Bliss OS 15, LineageOS 21 (x86_64 ISO), GrapheneOS factory image (note-only).
  - Alternatives for Surface/Xbox: NixOS 24.05 GNOME, Ubuntu 24.04.3 Desktop/Server references.

### Flashing and Images
- Auto-decompression on flash: streamed write for compressed images
  - `.img.xz`/`.xz` via `xz -dc | dd`
  - `.img.gz`/`.gz` via `gzip -dc | dd`
  - Shows progress gauge (percent unknown for streams, completes on finish).

### Preview
- Switched CLI image preview fallback from `viu` to `chafa` for broader Linux/macOS support.
- Kept external `image-view` as preferred preview when present.
- In-terminal preview uses `chafa | less -R`; user presses `q` to close.

### Dependencies and Setup
- First-run dependency installer now uses a minimal dialog gauge and logs details to `.deps_install.log`.
- Core and helpful tools installed: `dialog`, `jq`, `curl`/`wget`, `util-linux`, `coreutils`, `file`, `rsync`, `unzip`,
  plus preview/decompression helpers: `chafa`, `less`, `xz`/`xz-utils`, `gzip`.

### Terminal Hygiene
- When dialogs are cancelled or the app exits, restore terminal state and clear the screen (EXIT/INT/TERM traps).

## 2025-11-05

### Downloads
- Download dialog switched to script-helpers’ default dialog helpers.
- Gauge-only download: removed extra stdout prints during downloads.
- Gauge labels now use the human-friendly distro name.

### Etcher
- Downloads within Etcher also use friendly labels in the gauge and suppress extra prints.
