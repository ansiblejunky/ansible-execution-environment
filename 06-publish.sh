#!/bin/bash
# NAME:
#   06-publish.sh
# PURPOSE:
#   Publish Ansible Execution Environment to container registry
# USAGE:
#   ./06-publish.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/06-publish.sh


echo -e "\n--- Starting Publishing --- \n"
podman login $(ANSIBLE_EE_TARGET_HUB)
podman tag  localhost/$(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG)   localhost/$(ANSIBLE_EE_TARGET_NAME):latest
podman push localhost/$(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG)   $(ANSIBLE_EE_TARGET_HUB)/$(TARGET_PROJECT)/$(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG)
podman push localhost/$(ANSIBLE_EE_TARGET_NAME):latest          $(ANSIBLE_EE_TARGET_HUB)/$(TARGET_PROJECT)/$(ANSIBLE_EE_TARGET_NAME):latest
echo -e "\n--- Finished Publishing --- \n"