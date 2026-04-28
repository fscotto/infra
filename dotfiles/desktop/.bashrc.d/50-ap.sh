#!/bin/bash

ap() {
  export PLAYBOOK_DIR="${PLAYBOOK_DIR:-$HOME/AnsiblePlaybook}"

  (
    cd "$PLAYBOOK_DIR"

    local cmd=(ansible-playbook ansible/site.yml -l "$HOSTNAME" -K)

    if [ -n "$1" ]; then
      cmd+=(--tag "$1")
    fi

    printf '\033[0;36m+ %s\033[0m\n' "${cmd[*]}"
    "${cmd[@]}"
  )
}
