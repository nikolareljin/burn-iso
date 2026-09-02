# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning when applicable.

## 2026-09-01 — 2.1.0

### Added
- **A real NikOS ISO build, verified end to end.** `.github/workflows/nikos-iso.yml` downloads a stock Xubuntu 24.04.4 image, runs `recipes/nikos.yml` against it, and checks the result. Nothing in it is mocked. It runs on demand and automatically when the builder, the recipes or the workflow change, since that is when "does a real build still work?" is worth an hour.
- `scripts/verify-nikos-iso.sh` inspects a finished image rather than trusting the build log: ISO 9660, an El Torito boot record, the recipe's volume id, a plausible size, and then inside the root filesystem the NikOS CLI, its Plymouth theme, the Xfce session, LightDM, desktop configuration in `/etc/skel`, an emptied `/etc/machine-id` and no leftover `policy-rc.d`.
- `scripts/test-forge-nikos.sh` runs on every pull request and covers what the hour-long build should not be the first to catch: the recipe's base, output, `/etc/skel` handoff and pinned playbook ref, and the tag guard below.

### Fixed
- **`recipes/nikos.yml` skipped a role that cannot be skipped.** It carried `skip_tags: [github-setup]`, but `github-setup` is a role with no `tags:` key, and `--skip-tags` matches tags rather than role names. The skip did nothing. Confirmed against the playbook itself: `ansible-playbook site.yml --list-tags` reports `ai-local, always, education, music, network, never` and the `never`-gated opt-ins, with no `github-setup` among them.
- The recipe now skips `ai-local`, `network`, `music` and `education`, which are tags that exist. `ai-local` matters most: it pulls Ollama models, which are gigabytes and belong on the installed machine rather than in an ISO.
- **A recipe naming a tag the playbook does not define now fails the build.** The two failure modes are not symmetric: a bad `tags` entry runs less than intended and is obvious, while a bad `skip_tags` entry silently runs *more* than intended, which for an image build is the expensive direction. iso-forge asks the playbook with `--list-tags` and refuses to continue on a mismatch; an unreadable listing warns rather than blocking.

## 2026-09-01 — 2.0.2

### Fixed
- **The Debian package could not be built.** `debian/source/format` declared `3.0 (quilt)`, which requires an upstream tarball at `../isoforge_<version>.orig.tar.*`. This project has no separate upstream release, so `dpkg-source` refused with "no upstream tarball found" and the `deb` job failed the moment it was able to run at all. The package is native, and now says so.
- **The RPM could not be built.** The spec's `%autosetup` unpacks `Source0`, but no `Source0:` was declared, so `rpmbuild` stopped with "error: No source number 0". It now declares `%{name}-%{version}.tar.gz`, which is exactly the tarball and prefix `build_rpm_artifacts.sh` writes into `SOURCES`.

Both were invisible until 2.0.1 fixed the workflow permissions, because until then the release run was rejected before any job started.

### Changed
- `README.md` describes building images, lists `./forge` among the entrypoints, distinguishes it from `./build`, documents `isoforge build` for a system install, and drops the placeholder PPA target that the release workflow no longer uses.

## 2026-09-01 — 2.0.1

### Fixed
- **The release workflow had never run.** GitHub validates a called workflow's declared permissions against what the caller grants, before any job starts. `ci-helpers/deb-build.yml` declares `contents: write`, this repository's default workflow permission is `read`, and `.github/workflows/main.yml` granted nothing, so every push to `main` was rejected with a startup failure and the deb, PPA, RPM and Homebrew jobs never executed. Going back through the run history, `Main` has failed on every commit since March and produced no package at any point. The workflow now grants `contents: read` by default and `contents: write` only to the job whose callee asks for it.

## 2026-09-01 — 2.0.0

### Added
- **`isoforge build` remasters a base image into a custom installable ISO.** Until now the tool could only write images someone else had built; now `./forge --recipe recipes/nikos.yml` takes a stock Ubuntu or Xubuntu image, applies a recipe and writes an ISO that installs the finished system. The result lands in `download_dir`, so the existing flash path picks it up unchanged.
- Recipes are YAML: a base image, packages to install or remove, apt sources, PPAs and keys, flatpaks, files to overlay and scripts to run inside the image. A `recipe.local.yml` beside a recipe is merged over it, the same tracked-defaults and untracked-overrides split NikOS uses for `vars/main.yml` and `vars/local.yml`.
- Optional integrations, either or neither: a NikOS Ansible playbook run inside the image, and a distrodeck export read as a package list so a snapshot of a working machine becomes an ISO.
- Both Ubuntu casper layouts. A single `filesystem.squashfs` is unpacked, edited and squashed back. The layered `minimal.standard.squashfs` stack is mounted read-only as overlayfs lowerdirs so the build writes into a fresh upperdir, which is then squashed as a new top layer and registered in `install-sources.yaml`; rewriting a layer in place would mean deciding which files belong to which layer.
- Xubuntu 24.04, Xubuntu 26.04 and Ubuntu 26.04 in the distro catalog.
- `docs/BUILD.md`, and `scripts/test-forge-{recipe,distrodeck,image}.sh` wired into `./test`.

### Notes
- Building needs root, about 25 GB of scratch space and 20 to 40 minutes. `--dry-run` validates a recipe with none of that.
- Boot arguments are read back from the base image with `xorriso -report_el_torito as_mkisofs` rather than hand-written, because hand-written boot flags are the usual reason a remastered image will not start. The base image must stay readable for the whole build.
- Snaps cannot be installed into a chroot; a `snap` section in a distrodeck export is reported and skipped rather than silently dropped.
- Arch is not supported. `archiso` shares nothing with casper and needs its own pipeline.

## 2026-09-01

### Repository
- Repointed every in-repository reference from `burn-iso` to `iso-forge` in preparation for renaming the GitHub repository, so the repository URL, Pages path and published identity will match the `isoforge` CLI and package. The GitHub-side rename itself is a separate step tracked in `docs/REPOSITORY-RENAME.md`; until it lands, `nikolareljin/iso-forge` does not resolve. The CLI, package name, Homebrew formula and man page are unchanged.
- Updated clone URLs, packaging metadata, workflow inputs, Pages links and the clone-traffic badge to `nikolareljin/iso-forge`.

### Fixes
- `inc/burn.sh` now defaults `SCRIPT_HELPERS_DIR` to `scripts/script-helpers`, matching every other entrypoint. `./burn` previously exited with a missing-helpers error on a correctly initialized clone.
- Version metadata is aligned at `1.1.0` across `VERSION`, `debian/changelog` and `packaging/isoforge.spec`, which had drifted to `0.1.0-1`.
- `tools/gen-brew-formula.sh` now builds release URLs from bare `X.Y.Z` tags instead of a `v`-prefixed tag that is never created.
- Replaced the placeholder PPA target in `.github/workflows/main.yml`.
- `tools/*.sh` gated on the script-helpers helper being executable, but upstream ships `build_brew_tarball.sh`, `gen_brew_formula.sh`, `build_rpm_artifacts.sh` and `publish_homebrew.sh` mode 644. Four of the six wrappers therefore failed with a misleading "script-helpers not initialized" error. They now check for the file and invoke it with `bash`.
- `tools/build-deb.sh` relied on the helper's default `--prebuild "make man"`, which fails because this repository has no Makefile. It now passes `./tools/gen-man.sh` explicitly.
- `tools/gen-brew-formula.sh` repairs two defects in the upstream generator: its dependency block reaches the formula with literal `\n` separators, and it names the `bin` shim after `--entrypoint`, producing `bin/"inc/isoforge.sh"` instead of `bin/"isoforge"`. Both are corrected with `awk` and a temporary file, which also works on the macOS hosts that run Homebrew publishing.
- Added the `packaging/rpm/build/` rpmbuild tree to `.gitignore`; `tools/build-rpm.sh` creates it.
- Every `tools/*.sh` wrapper sourced `helpers.sh` before checking that the submodule was initialized. Under `set -e` that aborted with a bare shell error and the friendly message at the bottom was unreachable. The check now runs first, and the helper check is an early guard rather than a trailing branch.
- The `brew` job now passes an explicit `tarball_url`. `ci-helpers/homebrew-package.yml` defaults to a `v`-prefixed tag while `ci-helpers/auto-tag-release.yml` creates bare `X.Y.Z` tags, so the published formula pointed at a URL that does not exist.
- `README.md` no longer describes `image-view` as a submodule of this repository.

### Removed
- Deleted the unreferenced `inc/include.sh` and `inc/distros.sh`. Their distro tables were superseded by `config.json`, and `is_valid_iso` resolves from `scripts/script-helpers/lib/file.sh`.
- Dropped the stale `image-view` entry from `.gitmodules`; it had no gitlink in the index and collided with the path `ensure_image_view_available` downloads into.
- Stopped tracking `packaging/homebrew/isoforge.rb`. It is regenerated by `tools/gen-brew-formula.sh` from a freshly built tarball before publishing, so a committed copy carries a `sha256` that cannot match the release asset. Both `tools/gen-brew-formula.sh` and `tools/publish-homebrew.sh` write or read it at the same path as before.

## 2026-03-11

### TUI
- `Flash!` in `inc/isoforge.sh` now redirects users to drive selection when no drive is chosen, keeps the current image selection intact, and continues into the flash confirmation flow after a drive is picked.
- Added `scripts/test-flash-drive-redirect.sh` and wired it into `./test` to keep the redirect behavior covered.
- Download failures now persist their latest summary, source, URL, timestamp, and `/tmp` log path in session state so the details remain visible in the `isoforge` main status panel after the error dialog is dismissed.
- `./download` now prints the last tracked download failure summary and log path at the end of a failed run.
- Added `scripts/test-download-error-state.sh` and wired it into `./test` to keep the persisted error summary behavior covered.

## 2026-03-08

### TUI
- Main-menu actions in `inc/isoforge.sh` now restore the last committed selection state after a canceled or failed sub-flow, so Cancel consistently returns users to the main page without leaking partial image/drive/background choices.
- Added `scripts/test-cancel-flow.sh` and wired it into `./test` to keep cancel rollback behavior covered.

### Downloads
- Refactored download flows in `inc/isoforge.sh` and `inc/download.sh` to use script-helpers download methods (`download_file`/dialog-backed progress) instead of duplicated in-repo gauge implementations.
- Aligned `inc/download.sh` helper path default to `scripts/script-helpers` to match the script-helpers layout.

### Tooling
- Added canonical helper entrypoints:
  - `./build` -> `scripts/build.sh`
  - `./test` -> `scripts/test.sh`
  - `./update` -> `scripts/update-submodules.sh`
- Added build/test/update helper scripts with strict shell settings and reproducible local workflows.
- `scripts/update-submodules.sh` now supports `-r` for remote submodule refresh mode.

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
