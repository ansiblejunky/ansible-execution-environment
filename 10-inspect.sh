#!/bin/bash
# NAME:
#   10-inspect.sh
# PURPOSE:
#   Inspect Ansible Execution Environment podman image
# USAGE:
#   ./10-inspect.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/10-inspect.sh

echo -e "\n--- Starting Inspect --- \n"
podman inspect $(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG)
