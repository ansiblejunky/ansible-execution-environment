#!/bin/bash
# NAME:
#   06-publish.sh
# PURPOSE:
#   Publish Ansible Execution Environment to container registry
# USAGE:
#   ./06-publish.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/06-publish.sh

# Error handling
set -euo pipefail
IFS=$'\n\t'
trap 'rc=$?; echo >&2 "ERROR: command \"${BASH_COMMAND}\" exited with status ${rc} at ${BASH_SOURCE[0]}:${LINENO}"; exit ${rc}' ERR
if [[ "${ANSIBLE_EE_DEBUG:-}" =~ ^(1|true|yes)$ ]]; then
    set -x
fi

echo -e "\n--- Publishing: Start --- \n"
podman login $ANSIBLE_EE_TARGET_HUB
podman tag  localhost/$ANSIBLE_EE_TARGET_NAME:$ANSIBLE_EE_TARGET_TAG   localhost/$ANSIBLE_EE_TARGET_NAME:latest
podman push localhost/$ANSIBLE_EE_TARGET_NAME:$ANSIBLE_EE_TARGET_TAG   $ANSIBLE_EE_TARGET_HUB/$ANSIBLE_EE_TARGET_PROJECT/$ANSIBLE_EE_TARGET_NAME:$ANSIBLE_EE_TARGET_TAG
podman push localhost/$ANSIBLE_EE_TARGET_NAME:latest          $ANSIBLE_EE_TARGET_HUB/$ANSIBLE_EE_TARGET_PROJECT/$ANSIBLE_EE_TARGET_NAME:latest

# Generate README content
echo -e "\n--- Publishing: Generate README --- \n"
echo -e "--- Ansible Version --- \n"
podman container run -it --rm $ANSIBLE_EE_TARGET_NAME:$ANSIBLE_EE_TARGET_TAG ansible --version
echo -e "\n--- Ansible Collections --- \n"
podman container run -it --rm $ANSIBLE_EE_TARGET_NAME:$ANSIBLE_EE_TARGET_TAG ansible-galaxy collection list
echo -e "\n--- Publishing: Completed --- \n"
