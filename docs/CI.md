# CI

## Workflows

- `PR`: runs a shell syntax check for the main scripts.
- `Main`: builds Debian packages, uploads to PPA, builds RPM artifacts, and generates Homebrew tarballs/formulas.

## Required GitHub Secrets (PPA)

- `PPA_GPG_PRIVATE_KEY`: armored private key for signing the source package.
- `PPA_GPG_PASSPHRASE`: passphrase for the signing key.
- `PPA_SSH_PRIVATE_KEY`: SSH key registered with Launchpad.

## Required GitHub Variables (PPA)

- `PPA_GPG_KEY_ID`: key ID or fingerprint (non-secret).
- `PPA_PUBLISH_ENABLED`: set to `true` to enable the PPA publish job.

## Required GitHub Variables (Homebrew)

- `HOMEBREW_PUBLISH_ENABLED`: set to `true` to enable Homebrew publishing.
- `HOMEBREW_TAP_REPO`: target tap repo (e.g., `nikolareljin/homebrew-tap`).
- `HOMEBREW_TAP_BRANCH`: optional (default `main`).

## Required GitHub Secrets (Homebrew)

- `HOMEBREW_TAP_TOKEN`: GitHub token with push access to the tap repo.

## PPA target

Update `ppa_target` in `.github/workflows/main.yml`:

```
ppa:your-launchpad-id/isoforge
```

## Notes

- Debian source builds use `debuild` and the `debian/` metadata in this repo.
- RPM builds use the reusable `ci-helpers` workflow with `script-helpers` RPM helpers.
- Homebrew builds use the reusable `ci-helpers` workflow and can optionally publish to a tap repo.
