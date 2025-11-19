#!/bin/bash
# NAME:
#   04-build.sh
# PURPOSE:
#   Build Ansible Execution Environment using ansible-builder and podman
# USAGE:
#   ./04-build.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/04-build.sh

echo -e "\n--- Building: Lint to check syntax --- \n"
yamllint --no-warnings $1.yml $1/*.yml

echo -e "\n--- Building: Login to source hub --- \n"
podman login $(ANSIBLE_EE_SOURCE_HUB)

echo -e "\n--- Building: Create build context --- \n"
ansible-builder introspect \
    --file $(ANSIBLE_EE_TARGET_NAME).yml \
    --sanitize \
    --user-pip=$(ANSIBLE_EE_TARGET_NAME)/requirements.txt \
    --user-bindep=$(ANSIBLE_EE_TARGET_NAME)/bindep.txt 2>&1 | tee $(ANSIBLE_EE_TARGET_NAME)-ansible-builder.log

# Build the execution environment container
echo -e "\n--- Building: Build execution environment container --- \n"
ansible-builder build \
    --tag $(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG) \
    --verbosity $(ANSIBLE_EE_VERBOSITY) \
    --container-runtime podman 2>&1 | tee -a $(ANSIBLE_EE_TARGET_NAME)-ansible-builder.log

# Generate README content
echo -e "\n--- Building: Generate README --- \n"
echo -e "--- Ansible Version --- \n"
podman container run -it --rm $(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG) ansible --version
echo -e "\n--- Ansible Collections --- \n"
podman container run -it --rm $(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG) ansible-galaxy collection list
