# Choosing what goes into an image

`isoforge build` produces an image from a recipe, and a recipe that provisions
with Ansible currently produces exactly one result. This describes how choosing
*what* to provision is meant to work, and the defect that has to be fixed
first.

Nothing here is implemented yet. It is written down so the shape is agreed
before the code exists, and so the defect below is known rather than
discovered.

## Known limitation today

`ansible.tags` and `ansible.skip_tags` are passed to a single
`ansible-playbook` invocation. That is wrong for any playbook whose optional
roles are declared `tags: [never, <name>]`, which is the normal way to write an
opt-in role:

    - role: neovim
      tags: [never, neovim]

`--tags neovim` restricts the run to tasks carrying that tag. Roles with no
`tags:` key are not selected by it, so they do not run at all. A recipe setting
`ansible.tags` therefore installs the optional role and skips the base system,
and the image comes out looking like the stock base with one extra package
rather than like the system the playbook describes.

**Until this is fixed, set `ansible.skip_tags` only.** No recipe in this
repository sets `ansible.tags`, which is why the flaw has not produced a bad
image.

## Two passes, not one

A picker produces a request of the form "everything, minus these defaults, plus
these opt-ins". One invocation cannot express it. Two can:

1. `--skip-tags <defaults turned off>` — the whole system
2. `--tags <opt-ins turned on>` — only those roles

The second pass is skipped when nothing was opted in. This is how NikOS's own
installer has always run: the ISO build was the odd one out.

The recipe gains `ansible.optional_tags` for the second pass. Setting it
together with `ansible.tags` is refused, because combining the two on one run
is the defect itself.

## Where the list of choices comes from

From the provisioning repository, not from here.

A playbook that offers optional roles already knows which they are, which are
on by default, and what each is for. Restating that in a recipe creates a
second copy that drifts silently: a role added upstream is simply missing from
the picker, and nothing fails to say so.

So a provisioning repository publishes a manifest — tag, display name, whether
it is on by default, and a weight for the ones that cost gigabytes — and this
repository reads it from the pinned ref. The pin matters: the manifest is read
from the same commit the build provisions from, so the choices offered are the
choices that exist.

The tag guard already refuses a build when a recipe names a tag the playbook
does not define, so a stale list cannot produce a wrong image. It can only
produce a short menu.

## Which images can be a base

Only a casper-based live desktop image can be remastered this way, and the
picker should offer nothing else. Refusing a base up front with a reason is
worth a great deal more than failing twenty minutes into a build.

| Kind | Usable as a base | Why |
| --- | --- | --- |
| Ubuntu and Xubuntu desktop | yes | casper, and a desktop to provision |
| Ubuntu server | no | casper, but no desktop |
| Debian netinst | no | no casper; the layout detector rejects it |
| ARM `.img.xz`, Ventoy entries | no | not ISO images |

`config.json` marks the entries that qualify. An entry that does not is left
with a stated reason rather than silently omitted, so the absence is legible.

## What selection will look like

Non-interactive:

```bash
./forge --recipe recipes/nikos.yml --list-bundles
./forge --recipe recipes/nikos.yml --bundles neovim,zsh --no-bundles music,education
```

An unknown name is refused immediately, before anything is downloaded.

Interactive: `./isoforge` gains a **Build a custom ISO** entry — pick a base
from the buildable entries, tick bundles in a checklist seeded from the
manifest defaults, confirm a summary, build.

## Costs worth knowing before you pick

A build takes 30 to 60 minutes, most of it `mksquashfs`. Some bundles pull
model weights measured in gigabytes; the picker marks those and warns, and does
not refuse them. An image is as large as what you asked for.
