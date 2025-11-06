Burn ISO Utilities

Simple shell scripts for downloading popular Linux ISOs and burning them to a USB device using `dialog` for UI prompts.

Repository

- GitHub (SSH): git@github.com:nikolareljin/burn-iso.git
- GitHub (HTTPS): https://github.com/nikolareljin/burn-iso.git

Important: Clone With Submodules

- This repo uses a Git submodule in `./scripts` for shared helpers. Clone with `--recurse-submodules`.
- Fresh clone (SSH):
  - `git clone --recurse-submodules git@github.com:nikolareljin/burn-iso.git`
  - `cd burn-iso`
- Fresh clone (HTTPS):
  - `git clone --recurse-submodules https://github.com/nikolareljin/burn-iso.git`
  - `cd burn-iso`
- If you already cloned without submodules:
  - `git submodule sync --recursive`
  - `git submodule update --init --recursive`

Recent Changes

- Root commands are short symlinks (`./etcher`, `./download`, `./burn`, `./setup`).
- Actual app scripts were moved from `./scripts/*.sh` to `./inc/*.sh`.
- Scripts resolve the repo root at runtime so they work via symlinks or direct `bash ./inc/<name>.sh`.

Curated Distros (config.json)

- I expanded `config.json` with a validated mix spanning:
  - Daily use: Ubuntu 24.04.3, Debian 13.1, Fedora 41, openSUSE Leap 15.6, Linux Mint 22, Arch (latest)
  - Cybersecurity: Kali Linux (installer 2025.2)
  - Cloning/backup: Rescuezilla 2.4.2
  - Repair tools: SystemRescue 11.00, GParted Live, Hiren's BootCD PE
  - Antivirus: Dr.Web LiveDisk
  - 32-bit hardware: Debian 12.7 (i386), antiX 23 (386), TinyCore 15 (i386)
  - Media/music production: Ubuntu Studio 24.04.3

- Every URL in `config.json` was checked for HTTP 200 and no 404s at the time of update.
- Some projects (LibreELEC, OPNsense/pfSense, Raspberry Pi OS, Armbian, various photo-frame and magic mirror builds) typically distribute compressed images (`.img.xz`, `.iso.bz2`) or installers, not raw `.iso`. Those are not included here to avoid broken flashes. If you want, we can add support for auto‑decompressing images before flashing.

Symlinked entrypoints

- The root now contains simple entrypoints without the `.sh` suffix: `./etcher`, `./download`, `./burn`, `./setup`.
- These are symlinks pointing to the actual scripts in `./inc/*.sh`.
- This keeps the root clean and makes commands shorter to run.

Etcher for the CLI

- Use `./etcher` for a simple, Etcher-like flow in your terminal:
  - Select Image (download from curated list or pick a local .iso)
  - Select Drive (USB by default)
  - Flash (with progress gauge)

Submodule Layout

- Submodule `scripts/` points to `git@github.com:nikolareljin/script-helpers.git` and provides common helpers (logging, dialog, deps, file, etc.).
  - Tracks branch: `main`.

Clone With Submodules

- Fresh clone (SSH):
  - `git clone --recurse-submodules git@github.com:nikolareljin/burn-iso.git`
  - `cd burn-iso`
- Fresh clone (HTTPS):
  - `git clone --recurse-submodules https://github.com/nikolareljin/burn-iso.git`
  - `cd burn-iso`
- If already cloned without submodules:
  - `git submodule sync --recursive`
  - `git submodule update --init --recursive`

Update Submodule (main)

- Pull latest helper scripts from `main` and record the update:
  - `git submodule update --remote --recursive`
  - `git add scripts && git commit -m "Update script-helpers to latest main"`

Note: SSH access is required for the submodule URL `git@github.com:nikolareljin/script-helpers.git`. If needed, you can switch it to HTTPS using `git config -f .gitmodules submodule.scripts.url https://github.com/nikolareljin/script-helpers.git && git submodule sync --recursive`.

Install Dependencies

- Use the helper-powered setup script to install required tools (`dialog`, `curl`, `jq`, `wget`, `util-linux`, `coreutils`):
  - `./setup`
  - Optionally, pass additional packages: `./setup <pkg1> <pkg2> ...`
  - The scripts also attempt to auto-install missing dependencies at runtime using the script-helpers `deps` module.

Usage

- Etcher-like TUI:
  - `./etcher`

- Config-powered utilities:
  - Download from curated list (config.json): `./download`
  - Burn an ISO from your `download_dir` (or browse): `./burn`

Multi-ISO with Ventoy

- In `./etcher`, you can now select multiple ISO files (from your `download_dir`).
- If more than one ISO is selected, the tool switches to a Ventoy flow:
  - Installs Ventoy to the selected USB device (data is erased).
  - Optionally applies a custom background image (Ventoy theme plugin).
  - Copies the selected ISOs to the Ventoy partition, checking free space first.
  - If space is insufficient, you can deselect some ISOs to fit.

Background Image & Preview

- The tool will attempt to auto-download a matching `image-view` release binary for your OS/arch from GitHub if none is found.
- If you prefer to manage it yourself, the repo is also added as a submodule; you can build and place the binary at `image-view/image-view`.
- In `./etcher`, choose “Select Ventoy Background”, pick a `jpg/png/tga`, preview it, and it will be installed as a Ventoy theme background.

Ventoy Requirements

- The tool auto-detects Ventoy. If not found, it tries to install it:
  - via system package manager (`apt`, `dnf`, `pacman`) if available
  - otherwise it fetches the latest release from GitHub and unpacks under `./ventoy/`
- It looks for `./ventoy/Ventoy2Disk.sh`, `./tools/ventoy/Ventoy2Disk.sh`, or `Ventoy2Disk.sh` on `PATH`.
- Packages helpful for this flow (installed by `./setup`): `rsync`, `exfatprogs`/`exfat-utils`, `parted`.

Notes on layout

- App scripts live in `./inc/*.sh`; root-level commands are symlinks.
- The `scripts/` directory is a submodule providing helper libraries; app scripts use it via `SCRIPT_HELPERS_DIR`.
- Advanced users can invoke the underlying scripts with `bash ./inc/<name>.sh`, but the recommended way is via the root symlinks shown above.

Screenshots (CLI)

Layout and symlinks

```
$ ls -l
lrwxrwxrwx 1 user user   13 Nov  2  etcher   -> inc/etcher.sh
lrwxrwxrwx 1 user user   15 Nov  2  download -> inc/download.sh
lrwxrwxrwx 1 user user   11 Nov  2  burn     -> inc/burn.sh
lrwxrwxrwx 1 user user   12 Nov  2  setup    -> inc/setup.sh
drwxr-xr-x 2 user user 4096 Nov  2  inc/
drwxr-xr-x 5 user user 4096 Nov  2  scripts/   # helper submodule
```

Etcher-like flow

```
$ ./etcher
Image: <not selected>
Drive: <not selected>

Choose an action:
  image  Select Image
  drive  Select Drive
  flash  Flash!
  quit   Quit
```

Selecting an image from config

```
$ ./download
[dialog] Select one or more distros to download
  [ ] Ubuntu_24_04_amd64   Ubuntu 24.04 LTS (amd64)
  [x] SystemRescue_amd64   SystemRescue 10.01 (amd64)
  [ ] Fedora_amd64         Fedora Workstation 42 (x86_64)
...
```

Flashing progress

```
$ ./burn
Confirm Burn
  Image: /home/user/Downloads/iso_images/systemrescue-10.01-amd64.iso
  Drive: /dev/sdb

Flashing to /dev/sdb
[ 42% ] Writing... 420478976 bytes
```

Environment Overrides

- Set `SCRIPT_HELPERS_DIR` to point to a custom helpers location if not using the `scripts/` submodule path.

Configuration

- `config.json` controls the curated distro list and defaults:
  - `download_dir`: where downloads are saved (supports `~`).
  - `block_device_filter`: which drives to show; `usb` (default) or `any`.
  - `distros`: array of `{ id, label, url }` items used by the "download from list" option.

Example `config.json` snippet:

```
{
  "download_dir": "~/Downloads/iso_images",
  "block_device_filter": "usb",
  "distros": [
    { "id": "Ubuntu_24_04_amd64", "label": "Ubuntu 24.04 LTS (amd64)", "url": "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-desktop-amd64.iso" }
  ]
}
```

Notes

- Flashing may require elevated privileges; tools use `sudo` if available.
- Progress uses `dd status=progress` and a `dialog` gauge; total percentage is based on ISO size.
