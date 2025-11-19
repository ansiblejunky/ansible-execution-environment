#!/bin/bash
# 00-envs-console.sh
# Set environment variables for Ansible Galaxy and Execution Environment builds using console.redhat.com
# Usage: export AAP_TOKEN=<your_refresh_token>
#        source 00-envs-console.sh

# Ensure the script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script is intended to be sourced: source 00-envs-console.sh <target_name>"
  exit 1
fi

# Ensure target_name parameter is provided
if [[ -z "$1" ]]; then
    echo "Usage: source 00-envs-console.sh <target_name>"
    return 1
fi

# Ensure AAP_TOKEN is set
if [[ -z "${AAP_TOKEN}" ]]; then
    echo "Environment Variable 'AAP_TOKEN' is not set. Please get it from console.redhat.com."
    return 1
fi

# Refresh the console.redhat.com offline token since it expires every 30 days
curl https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token \
    -d grant_type=refresh_token \
    -d client_id="cloud-services" \
    -d refresh_token=${AAP_TOKEN} \
    --fail --silent --show-error --output /dev/null

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
export ANSIBLE_EE_TARGET_NAME=$1

export ANSIBLE_EE_BASE_IMAGE=registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest

export ANSIBLE_GALAXY_SERVER_LIST=certified,validated,community
export ANSIBLE_GALAXY_SERVER_CERTIFIED_URL=https://console.redhat.com/api/automation-hub/content/published/
export ANSIBLE_GALAXY_SERVER_CERTIFIED_AUTH_URL=https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
export ANSIBLE_GALAXY_SERVER_CERTIFIED_TOKEN=${AAP_TOKEN}
export ANSIBLE_GALAXY_SERVER_VALIDATED_URL=https://console.redhat.com/api/automation-hub/content/validated/
export ANSIBLE_GALAXY_SERVER_VALIDATED_AUTH_URL=https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
export ANSIBLE_GALAXY_SERVER_VALIDATED_TOKEN=${AAP_TOKEN}
export ANSIBLE_GALAXY_SERVER_COMMUNITY_URL=https://galaxy.ansible.com

echo "Configured environment variables for console.redhat.com"
