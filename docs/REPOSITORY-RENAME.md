# Repository rename: burn-iso to iso-forge

## Intent

The repository will be renamed from `burn-iso` to `iso-forge` so its GitHub
name, clone URL and GitHub Pages path match the existing IsoForge CLI and
package name. This is a repository and URL migration only: the `isoforge`
command and package identity remain unchanged.

## Required order

1. Finish and merge this documentation and the corresponding keystone backlog
   item before changing the GitHub repository name.
2. Inventory every owned-repository reference to `nikolareljin/burn-iso` and
   classify it as source, package metadata, workflow, documentation, release
   URL, Pages URL or GitHub setting.
3. Rename the GitHub repository, retaining GitHub's redirect from the old URL.
4. Update the local checkout, origin remote, Pages configuration and every
   inventoried owned reference to `nikolareljin/iso-forge`.
5. Publish the site at `/iso-forge/`, verify old repository URLs redirect, and
   verify no active owned code or configuration still names `burn-iso`.

## Migration checklist

- GitHub repository name, description, homepage, topics, Pages configuration,
  release links and repository redirects.
- Local clone directory and `origin` fetch/push URL.
- README clone commands, badges, documentation, source URLs and support links.
- Debian metadata, RPM spec, Homebrew formula/generator and release tarball
  URLs.
- GitHub Actions workflow configuration, release targets and Pages links.
- References in every owned repository, including NikOS, distrodeck and the
  shared tool-suite navigation.

Live progress belongs in the keystone issue created from its backlog item;
this document intentionally records the migration contract rather than status.
