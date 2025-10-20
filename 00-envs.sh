#!/bin/bash
# NAME:
#   00-envs.sh
# PURPOSE:
#   Set environment variables for Ansible Galaxy and Execution Environment builds
# USAGE:
#   export AAP_TOKEN=<your_token>
#   source 00-envs.sh [--hub | --console]
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/00-envs.sh


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

# Set Ansible Galaxy environment variables using Automation Hub
if [[ "$1" == "--hub" ]]; then
    if [[ -z "${AAP_TOKEN}" ]]; then
        echo "Environment Variable 'AAP_TOKEN' is not set. Please get it from either your Automation Hub or console.redhat.com."
        return 1
    fi
    export ANSIBLE_GALAXY_SERVER_LIST=certified,validated,community
    export ANSIBLE_GALAXY_SERVER_CERTIFIED_URL=https://$2/pulp_ansible/galaxy/rh-certified/
    export ANSIBLE_GALAXY_SERVER_CERTIFIED_TOKEN=${AAP_TOKEN}
    export ANSIBLE_GALAXY_SERVER_VALIDATED_URL=https://$2/pulp_ansible/galaxy/validated/
    export ANSIBLE_GALAXY_SERVER_VALIDATED_TOKEN=${AAP_TOKEN}
    export ANSIBLE_GALAXY_SERVER_COMMUNITY_URL=https://galaxy.ansible.com
    echo "Configured for Automation Hub"

# # Set Ansible Galaxy environment variables using console.redhat.com
elif [[ "$1" == "--console" ]]; then
    if [[ -z "${AAP_TOKEN}" ]]; then
        echo "Environment Variable 'AAP_TOKEN' is not set. Please get it from either your Automation Hub or console.redhat.com."
        return 1
    fi

    # Refresh the console.redhat.com offline token since it expires every 30 days
    curl https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token \
        -d grant_type=refresh_token \
        -d client_id="cloud-services" \
        -d refresh_token=${AAP_TOKEN} \
        --fail --silent --show-error --output /dev/null

    export ANSIBLE_GALAXY_SERVER_LIST=certified,validated,community
    export ANSIBLE_GALAXY_SERVER_CERTIFIED_URL=https://console.redhat.com/api/automation-hub/content/published/
    export ANSIBLE_GALAXY_SERVER_CERTIFIED_AUTH_URL=https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
    export ANSIBLE_GALAXY_SERVER_CERTIFIED_TOKEN=${AAP_TOKEN}
    export ANSIBLE_GALAXY_SERVER_VALIDATED_URL=https://console.redhat.com/api/automation-hub/content/validated/
    export ANSIBLE_GALAXY_SERVER_VALIDATED_AUTH_URL=https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
    export ANSIBLE_GALAXY_SERVER_VALIDATED_TOKEN=${AAP_TOKEN}
    export ANSIBLE_GALAXY_SERVER_COMMUNITY_URL=https://galaxy.ansible.com
    echo "Configured for Console"
else
    echo "Usage: source galaxy.sh --hub gateway.com | --console"
    return 1
fi

echo "Ansible Galaxy Environment Variables Have Been Configured"
