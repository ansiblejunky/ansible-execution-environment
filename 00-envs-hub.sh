#!/bin/bash
# 00-envs-hub.sh
# Set environment variables for Ansible Galaxy and Execution Environment builds using Automation Hub
# Usage: export AAP_TOKEN=<your_token>
#        source 00-envs-hub.sh <hub_host>

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script is intended to be sourced: source 00-envs-hub.sh <hub_host>"
  exit 1
fi

if [[ -z "$1" ]]; then
    echo "Usage: source 00-envs-hub.sh <hub_host>"
    return 1
fi

if [[ -z "${AAP_TOKEN}" ]]; then
    echo "Environment Variable 'AAP_TOKEN' is not set. Please get it from your Automation Hub."
    return 1
fi

# Unset any previous environment variables
for var in $(env | grep '^ANSIBLE_GALAXY_SERVER_' | cut -d= -f1); do
  unset "$var"
done
for var in $(env | grep '^ANSIBLE_EE_' | cut -d= -f1); do
  unset "$var"
done

export ANSIBLE_EE_VERBOSITY=3
export ANSIBLE_EE_SOURCE_HUB=registry.redhat.io
export ANSIBLE_EE_SOURCE_TOKEN=${AAP_TOKEN}
export ANSIBLE_EE_TARGET_TAG=v1
export ANSIBLE_EE_TARGET_HUB=quay.io
export ANSIBLE_EE_TARGET_PROJECT=jwadleig
export ANSIBLE_EE_TARGET_NAME=ansible-${TARGET_NAME}

export ANSIBLE_EE_BASE_IMAGE=registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest

export ANSIBLE_GALAXY_SERVER_LIST=certified,validated,community
export ANSIBLE_GALAXY_SERVER_CERTIFIED_URL=https://$1/pulp_ansible/galaxy/rh-certified/
export ANSIBLE_GALAXY_SERVER_CERTIFIED_TOKEN=${AAP_TOKEN}
export ANSIBLE_GALAXY_SERVER_VALIDATED_URL=https://$1/pulp_ansible/galaxy/validated/
export ANSIBLE_GALAXY_SERVER_VALIDATED_TOKEN=${AAP_TOKEN}
export ANSIBLE_GALAXY_SERVER_COMMUNITY_URL=https://galaxy.ansible.com

echo "Configured environment variables for Automation Hub ($1)"
