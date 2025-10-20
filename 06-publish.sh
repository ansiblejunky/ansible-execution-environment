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
podman login $(TARGET_HUB)
podman tag  localhost/$(TARGET_NAME):$(TARGET_TAG)   localhost/$(TARGET_NAME):latest
podman push localhost/$(TARGET_NAME):$(TARGET_TAG)   $(TARGET_HUB)/$(TARGET_PROJECT)/$(TARGET_NAME):$(TARGET_TAG)
podman push localhost/$(TARGET_NAME):latest          $(TARGET_HUB)/$(TARGET_PROJECT)/$(TARGET_NAME):latest
echo -e "\n--- Finished Publishing --- \n"