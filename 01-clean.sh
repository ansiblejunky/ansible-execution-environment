#!/bin/bash
# NAME:
#   01-clean.sh
# PURPOSE:
#   Clean temporary files and podman images
# USAGE:
#   ./01-clean.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/01-clean.sh

echo -e "\n--- Cleaning: Remove temporary files --- \n"
rm -rf \
    context \
    ansible-navigator.log \
    ansible-builder.log \
    ansible-builder.bak.log \
    collections
echo -e "\n--- Cleaning: Remove podman images --- \n"
podman image prune -a