#!/bin/bash
# NAME:
#   04-build.sh
# PURPOSE:
#   Build Ansible Execution Environment using ansible-builder and podman
# USAGE:
#   ./04-build.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/04-build.sh

echo -e "\n--- Building: Lint first --- \n"
yamllint .

echo -e "\n--- Building: Login to source hub --- \n"
podman login $(SOURCE_HUB)

echo -e "\n--- Building: Prepare ansible.cfg --- \n"
if [ -a ansible.cfg ] ; \
then \
    echo "Using existing ansible.cfg"; \
else \
    envsubst < ansible.cfg.template > ./ansible.cfg; \
fi;

echo -e "\n--- Building: Create build context --- \n"
ansible-builder introspect \
    --file $(TARGET_NAME).yml \
    --sanitize \
    --user-pip=$(TARGET_NAME)/requirements.txt \
    --user-bindep=$(TARGET_NAME)/bindep.txt 2>&1 | tee $(TARGET_NAME)-ansible-builder.log

# Build the execution environment container
echo -e "\n--- Building: Build execution environment container --- \n"
ansible-builder build \
    --tag $(TARGET_NAME):$(TARGET_TAG) \
    --verbosity $(VERBOSITY) \
    --container-runtime podman 2>&1 | tee -a $(TARGET_NAME)-ansible-builder.log

# Generate README content
echo -e "\n--- Building: Generate README --- \n"
echo -e "--- Ansible Version --- \n"
podman container run -it --rm $(TARGET_NAME):$(TARGET_TAG) ansible --version
echo -e "\n--- Ansible Collections --- \n"
podman container run -it --rm $(TARGET_NAME):$(TARGET_TAG) ansible-galaxy collection list
