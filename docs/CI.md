# CI

## Workflows

- `PR`: runs a shell syntax check for the main scripts.
- `Main`: builds Debian packages, uploads to PPA, and builds RPM artifacts.

## Required GitHub Secrets (PPA)

- `PPA_GPG_PRIVATE_KEY`: armored private key for signing the source package.
- `PPA_GPG_PASSPHRASE`: passphrase for the signing key.
- `PPA_GPG_KEY_ID`: key ID or fingerprint.
- `PPA_SSH_PRIVATE_KEY`: SSH key registered with Launchpad.

## PPA target

Update `ppa_target` in `.github/workflows/main.yml`:

```
ppa:your-launchpad-id/isoforge
```

## Notes

- Debian source builds use `debuild` and the `debian/` metadata in this repo.
- RPM builds use `tools/build-rpm.sh` and publish artifacts to the workflow run.
