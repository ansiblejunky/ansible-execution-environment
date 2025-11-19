#!/bin/bash
# NAME:
#   40-shell.sh
# PURPOSE:
#   Launch a shell inside the Ansible Execution Environment container
# USAGE:
#   ./40-shell.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/40-shell.sh


echo -e "\n--- Starting Shell --- \n"

# Creates and starts a new container shell from a specified image
# Will remove the container upon exit
# Will mount the current directory into /workdir in the container
# Will first pull image if not present locally
podman run -it --rm $(ANSIBLE_EE_TARGET_NAME):$(ANSIBLE_EE_TARGET_TAG) /bin/bash
