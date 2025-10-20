#!/bin/bash
echo -e "\n--- Starting Functional Testing --- \n"
ansible-navigator run \
    playbook.yml \
    --container-engine podman \
    --mode stdout \
    --execution-environment-image $(TARGET_NAME):$(TARGET_TAG)
