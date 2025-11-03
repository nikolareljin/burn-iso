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
