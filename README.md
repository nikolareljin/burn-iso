Burn ISO Utilities

Simple shell scripts for downloading popular Linux ISOs and burning them to a USB device using `dialog` for UI prompts.

Etcher for the CLI

- Use `etcher.sh` for a simple, Etcher-like flow in your terminal:
  - Select Image (download from curated list or pick a local .iso)
  - Select Drive (USB by default)
  - Flash (with progress gauge)

Submodule Layout

- Submodule `scripts/` points to `git@github.com:nikolareljin/script-helpers.git` and provides common helpers (logging, dialog, deps, file, etc.).
  - Tracks branch: `main`.

Clone With Submodules

- Fresh clone (recommended):
  - `git clone --recurse-submodules <this-repo-url>`
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
  - `bash ./setup.sh`
  - Optionally, pass additional packages: `bash ./setup.sh <pkg1> <pkg2> ...`
  - The scripts also attempt to auto-install missing dependencies at runtime using the script-helpers `deps` module.

Usage

- Etcher-like TUI:
  - `bash ./etcher.sh`

- Config-powered utilities:
  - Download from curated list (config.json): `bash ./download.sh`
  - Burn an ISO from your `download_dir` (or browse): `bash ./burn.sh`

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
