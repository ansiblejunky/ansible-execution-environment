#!/bin/bash
# Container-based testing for Ansible Execution Environment
# This script tests an execution environment in a container without AAP requirements

set -e  # Exit on error
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."  # Move to project root

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file"
  source .env
fi

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "==================================================================="
echo "   Container-Based Testing for Ansible Execution Environments"
echo "==================================================================="

# Set default values
CONTAINER_ENGINE=${CONTAINER_ENGINE:-podman}
TARGET_TAG=${TARGET_TAG:-latest}
TARGET_NAME=${TARGET_NAME:-ansible-ee-minimal}

# Display configuration
echo -e "${YELLOW}Test Configuration:${NC}"
echo -e "  Container Engine: ${CONTAINER_ENGINE}"
echo -e "  Target Image: ${TARGET_NAME}:${TARGET_TAG}"

# Check if container engine is installed
if ! command -v $CONTAINER_ENGINE &> /dev/null; then
    echo -e "${RED}Error: ${CONTAINER_ENGINE} is not installed${NC}"
    exit 1
fi

# Create a temporary build directory
BUILD_DIR=$(mktemp -d)
echo -e "\n${YELLOW}Creating temporary test directory: ${BUILD_DIR}${NC}"

# Create test playbook
cat > ${BUILD_DIR}/test-playbook.yml <<EOL
---
- name: Verify Execution Environment
  hosts: localhost
  gather_facts: true
  tasks:
    - name: Gather Ansible version
      ansible.builtin.debug:
        msg: "Running Ansible {{ ansible_version.full }} in execution environment"
    
    - name: Verify Python is installed
      ansible.builtin.command: python3 --version
      register: python_version
      changed_when: false
    
    - name: Show Python version
      ansible.builtin.debug:
        msg: "{{ python_version.stdout }}"
    
    - name: List installed collections
      ansible.builtin.command: ansible-galaxy collection list
      register: collection_list
      changed_when: false
    
    - name: Show installed collections
      ansible.builtin.debug:
        msg: "{{ collection_list.stdout_lines }}"
    
    - name: List installed Python packages
      ansible.builtin.command: pip3 list
      register: pip_list
      changed_when: false
    
    - name: Show installed Python packages
      ansible.builtin.debug:
        msg: "{{ pip_list.stdout_lines }}"
EOL

# Pull the container image
echo -e "\n${YELLOW}Pulling container image for testing...${NC}"
$CONTAINER_ENGINE pull registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest

# Run the container with the mounted project
echo -e "\n${YELLOW}Starting container for testing...${NC}"
echo -e "${YELLOW}This will test the execution environment${NC}"

$CONTAINER_ENGINE run -it --rm \
  -v $PWD:/home/runner/project:Z \
  -v ${BUILD_DIR}:/home/runner/test:Z \
  -w /home/runner/project \
  registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest \
  ansible-playbook /home/runner/test/test-playbook.yml -v

# Check the result
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}Container-based testing completed successfully!${NC}"
else
    echo -e "\n${RED}Container-based testing failed.${NC}"
    echo "Please check the logs for details."
    exit 1
fi

# Clean up
rm -rf ${BUILD_DIR}
echo -e "\n${GREEN}Temporary test directory removed${NC}" 