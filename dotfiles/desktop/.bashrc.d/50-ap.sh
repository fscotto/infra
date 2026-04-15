#!/bin/bash

ap() {
  export PLAYBOOK_DIR="${PLAYBOOK_DIR:-$HOME/AnsiblePlaybook}"

  local cmd=(ansible-playbook "$PLAYBOOK_DIR/ansible/site.yml" -l "$HOSTNAME" -K)

  if [ -n "$1" ]; then
    cmd+=(--tag "$1")
  fi

  printf '+ %s\n' "${cmd[*]}"
  "${cmd[@]}"
}
