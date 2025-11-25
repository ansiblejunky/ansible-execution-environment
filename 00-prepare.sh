#!/bin/bash
# 00-prepare.sh
# Set environment variables for Ansible Galaxy and Execution Environment builds.
# Default: console.redhat.com (console mode). If a second parameter (hub_host)
# is provided, configure for Automation Hub (hub mode).
# Usage (console default):
#   export AAP_TOKEN=<your_refresh_token>
#   source 00-prepare.sh <target_name>
# Usage (hub mode):
#   export AAP_TOKEN=<your_token>
#   source 00-prepare.sh <target_name> <hub_host>

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script is intended to be sourced: source 00-prepare.sh <target_name> [hub_host]"
  exit 1
fi

# Ensure target_name parameter is provided
if [[ -z "$1" ]]; then
    echo "Usage: source 00-prepare.sh <target_name> [hub_host]"
    return 1
fi

# Ensure AAP_TOKEN is set
if [[ -z "${AAP_TOKEN}" ]]; then
    echo "Environment Variable 'AAP_TOKEN' is not set. Please get it from console.redhat.com or your Automation Hub."
    return 1
fi

# Determine mode: default is console (no HUB_HOST), if $2 present use hub mode
TARGET_NAME="$1"
HUB_HOST=""
if [[ -n "$2" ]]; then
    HUB_HOST="$2"
fi

# If console mode, refresh the offline token (console tokens expire frequently)
if [[ -z "${HUB_HOST}" ]]; then
    curl https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token \
        -d grant_type=refresh_token \
        -d client_id="cloud-services" \
        -d refresh_token=${AAP_TOKEN} \
        --fail --silent --show-error --output /dev/null
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
export ANSIBLE_EE_TARGET_TAG=v1 #TODO: This will change per build
export ANSIBLE_EE_TARGET_HUB=quay.io
export ANSIBLE_EE_TARGET_PROJECT=jwadleig
export ANSIBLE_EE_TARGET_NAME=${TARGET_NAME}

# Set Galaxy server list common to both modes
export ANSIBLE_GALAXY_SERVER_LIST=certified,validated,community

if [[ -n "${HUB_HOST}" ]]; then
    # Automation Hub (custom host) mode
    export ANSIBLE_EE_SOURCE_TOKEN=${AAP_TOKEN}

    export ANSIBLE_GALAXY_SERVER_CERTIFIED_URL=https://${HUB_HOST}/pulp_ansible/galaxy/rh-certified/
    export ANSIBLE_GALAXY_SERVER_CERTIFIED_TOKEN=${AAP_TOKEN}
    export ANSIBLE_GALAXY_SERVER_VALIDATED_URL=https://${HUB_HOST}/pulp_ansible/galaxy/validated/
    export ANSIBLE_GALAXY_SERVER_VALIDATED_TOKEN=${AAP_TOKEN}
    export ANSIBLE_GALAXY_SERVER_COMMUNITY_URL=https://galaxy.ansible.com

    echo "Configured environment variables for Automation Hub (${HUB_HOST})"
else
    # console.redhat.com (default) mode
    export ANSIBLE_GALAXY_SERVER_CERTIFIED_URL=https://console.redhat.com/api/automation-hub/content/published/
    export ANSIBLE_GALAXY_SERVER_CERTIFIED_AUTH_URL=https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
    export ANSIBLE_GALAXY_SERVER_CERTIFIED_TOKEN=${AAP_TOKEN}
    export ANSIBLE_GALAXY_SERVER_VALIDATED_URL=https://console.redhat.com/api/automation-hub/content/validated/
    export ANSIBLE_GALAXY_SERVER_VALIDATED_AUTH_URL=https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
    export ANSIBLE_GALAXY_SERVER_VALIDATED_TOKEN=${AAP_TOKEN}
    export ANSIBLE_GALAXY_SERVER_COMMUNITY_URL=https://galaxy.ansible.com

    echo "Configured environment variables for console.redhat.com"
fi

echo -e "\n--- Prepare: Remove temp files --- \n"
rm -rf \
    context \
    *.log \
    tmp_collections

echo -e "\n--- Prepare: Remove containers --- \n"
podman container prune -f
echo -e "\n--- Prepare: Remove images --- \n"
podman image prune -a

echo -e "\n--- Prepare: Ensure system requirements --- \n"
sudo loginctl enable-linger $(whoami)
sudo dnf install -y podman gettext rsync unzip tar jq git vi vim expect
echo -e "\n--- Prepare: Completed --- \n"