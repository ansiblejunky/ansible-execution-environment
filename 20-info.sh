#!/bin/bash
# NAME:
#   20-info.sh
# PURPOSE:
#   Display Ansible version and installed collections in the Ansible Execution Environment podman image
# USAGE:
#   ./20-info.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/20-info.sh

echo -e "\n--- Starting Information --- \n"
echo -e "--- Python Version --- \n"
podman container run -it --rm $(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG) python --version
echo -e "--- Ansible Version --- \n"
podman container run -it --rm $(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG) ansible --version
echo -e "\n--- Ansible Collections --- \n"
podman container run -it --rm $(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG) ansible-galaxy collection list
