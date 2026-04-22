#!/bin/bash
# NAME:
#   04-build.sh
# PURPOSE:
#   Build Ansible Execution Environment using ansible-builder and podman
# USAGE:
#   ./04-build.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/04-build.sh

# Error handling
set -euo pipefail
IFS=$'\n\t'
trap 'rc=$?; echo >&2 "ERROR: command \"${BASH_COMMAND}\" exited with status ${rc} at ${BASH_SOURCE[0]}:${LINENO}"; exit ${rc}' ERR
if [[ "${ANSIBLE_EE_DEBUG:-}" =~ ^(1|true|yes)$ ]]; then
    set -x
fi

echo -e "\n--- Building: Lint to check syntax --- \n"
yamllint --no-warnings --list-files .

echo -e "\n--- Building: Login to source hub --- \n"
echo "Logging into $ANSIBLE_EE_SOURCE_HUB..."
podman login $ANSIBLE_EE_SOURCE_HUB

# Build the execution environment container
echo -e "\n--- Building: Start --- \n"
ansible-builder build \
    -f $ANSIBLE_EE_TARGET_NAME.yml \
    --tag $ANSIBLE_EE_TARGET_NAME:$ANSIBLE_EE_TARGET_TAG \
    --verbosity $ANSIBLE_EE_VERBOSITY \
    --container-runtime podman \
    --squash all \
    --build-arg ANSIBLE_GALAXY_SERVER_LIST \
    --build-arg ANSIBLE_GALAXY_SERVER_CERTIFIED_URL \
    --build-arg ANSIBLE_GALAXY_SERVER_CERTIFIED_AUTH_URL \
    --build-arg ANSIBLE_GALAXY_SERVER_CERTIFIED_TOKEN \
    --build-arg ANSIBLE_GALAXY_SERVER_VALIDATED_URL \
    --build-arg ANSIBLE_GALAXY_SERVER_VALIDATED_AUTH_URL \
    --build-arg ANSIBLE_GALAXY_SERVER_VALIDATED_TOKEN \
    --build-arg ANSIBLE_GALAXY_SERVER_COMMUNITY_URL 2>&1 | tee -a ansible-builder.log
