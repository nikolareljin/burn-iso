#!/usr/bin/env bash
# Running an Ansible playbook, such as NikOS, inside the image being built.
#
# NikOS is written for a machine someone is sitting at: site.yml derives
# nikos_home and nikos_user from the controller's environment, and the theming
# role writes into that user's ~/.config. In a chroot there is no such user and
# the environment resolves to root, so the overrides below point the per-user
# half at /etc/skel. Every account the installer creates then inherits it,
# which is what "ship NikOS as an ISO" has to mean.

forge_ansible_available() {
  recipe_has '.ansible'
}

forge_ansible() {
  local rootfs="$1"
  forge_ansible_available || return 0

  local repo ref playbook dest
  repo=$(recipe_get '.ansible.repo')
  ref=$(recipe_get '.ansible.ref // ""')
  playbook=$(recipe_get '.ansible.playbook')
  dest=$(recipe_get '.ansible.dest // "/opt/nikos"')

  log_info "Provisioning with Ansible: $repo${ref:+ @ $ref}"

  forge_in_chroot "command -v ansible-playbook >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y --no-install-recommends ansible-core git ca-certificates)" || {
    log_error "Could not install ansible-core inside the image"
    return 1
  }

  forge_in_chroot "rm -rf '$dest' && git clone --depth 1 ${ref:+--branch '$ref'} --recurse-submodules '$repo' '$dest'" || {
    log_error "Could not clone $repo${ref:+ at $ref}"
    return 1
  }

  # Requirements are optional; a playbook with no collections still works.
  forge_in_chroot_soft "cd '$dest' && [ -f requirements.yml ] && ansible-galaxy collection install -r requirements.yml || true"

  local -a args=()
  local skel_home
  skel_home=$(recipe_get '.ansible.skel_home // "/etc/skel"')

  args+=(-e "nikos_home=$skel_home")
  args+=(-e "nikos_user=root")

  local extra_count i key val
  extra_count=$(recipe_get '.ansible.extra_vars // {} | length')
  if ((extra_count > 0)); then
    while IFS=$'\t' read -r key val; do
      [[ -n "$key" ]] || continue
      args+=(-e "$key=$val")
    done < <(jq -r '.ansible.extra_vars // {} | to_entries[] | "\(.key)\t\(.value)"' <<<"$RECIPE_JSON")
  fi

  local -a tags skips
  mapfile -t tags < <(recipe_list '.ansible.tags')
  mapfile -t skips < <(recipe_list '.ansible.skip_tags')
  ((${#tags[@]}))  && args+=(--tags "$(IFS=,; echo "${tags[*]}")")
  ((${#skips[@]})) && args+=(--skip-tags "$(IFS=,; echo "${skips[*]}")")

  local inventory
  inventory=$(recipe_get '.ansible.inventory // "inventory/local"')

  # --connection=local because the chroot is the target; ansible must not try
  # to ssh anywhere.
  local cmd="cd '$dest' && ansible-playbook '$playbook' -i '$inventory' --connection=local"
  local a
  for a in "${args[@]}"; do
    cmd+=" $(printf '%q' "$a")"
  done

  log_info "  $cmd"
  if ! forge_in_chroot "$cmd"; then
    log_error "The playbook failed. Tasks that need a running desktop session cannot"
    log_error "run at build time; list them under ansible.skip_tags in the recipe."
    return 1
  fi
}
