#!/bin/bash
set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Logging functions
log_info() { echo "[INFO] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_debug() { [[ "${VERBOSE:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }

# Error handling
trap 'log_error "Error on line $LINENO"' ERR

# Default values
VERBOSE=0
CLEANUP=1
TEST_IMAGE="ansible-ee-test:latest"
TEST_PLAYBOOK="${PROJECT_ROOT}/files/testing/test-playbook.yml"

# Usage function
show_usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Run end-to-end tests for the Ansible Execution Environment.

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --no-cleanup        Don't cleanup test artifacts
    --image NAME        Use specific test image (default: ${TEST_IMAGE})
    --playbook PATH     Use specific test playbook (default: ${TEST_PLAYBOOK})
EOF
}

# Function to run environment setup
run_environment_setup() {
    log_info "Setting up test environment"
    
    # Run bootstrap environment script
    "${SCRIPT_DIR}/bootstrap_env.sh" || {
        log_error "Environment setup failed"
        return 1
    }
    
    # Run validation script
    "${SCRIPT_DIR}/bootstrap_validate.sh" || {
        log_error "Environment validation failed"
        return 1
    }
}

# Function to build test image
build_test_image() {
    log_info "Building test image: ${TEST_IMAGE}"
    
    # Build image using ansible-builder
    ansible-builder build \
        --tag="${TEST_IMAGE}" \
        --container-runtime=podman \
        --verbosity=2 || {
        log_error "Image build failed"
        return 1
    }
}

# Function to create test playbook
create_test_playbook() {
    log_info "Creating test playbook"
    
    mkdir -p "$(dirname "${TEST_PLAYBOOK}")"
    
    cat > "${TEST_PLAYBOOK}" <<EOF
---
- name: Test Playbook
  hosts: localhost
  gather_facts: true
  
  tasks:
    - name: Verify Python
      command: python3 --version
      register: python_version
      changed_when: false
    
    - name: Verify Ansible
      command: ansible --version
      register: ansible_version
      changed_when: false
    
    - name: Verify Collections
      command: ansible-galaxy collection list
      register: collections
      changed_when: false
    
    - name: Display Results
      debug:
        msg: 
          - "Python Version: {{ python_version.stdout }}"
          - "Ansible Version: {{ ansible_version.stdout_lines[0] }}"
          - "Collections: {{ collections.stdout_lines | length }} installed"
EOF
}

# Function to run test playbook
run_test_playbook() {
    log_info "Running test playbook"
    
    # Create test inventory
    local test_inventory="${PROJECT_ROOT}/files/testing/test-inventory.yml"
    mkdir -p "$(dirname "${test_inventory}")"
    echo "localhost ansible_connection=local" > "${test_inventory}"
    
    # Run playbook using ansible-navigator
    ansible-navigator run "${TEST_PLAYBOOK}" \
        --inventory="${test_inventory}" \
        --container-engine=podman \
        --execution-environment-image="${TEST_IMAGE}" \
        --mode=stdout || {
        log_error "Playbook execution failed"
        return 1
    }
}

# Function to cleanup test artifacts
cleanup_test_artifacts() {
    if [[ "${CLEANUP}" != "1" ]]; then
        log_info "Skipping cleanup as requested"
        return 0
    fi
    
    log_info "Cleaning up test artifacts"
    
    # Remove test playbook and inventory
    rm -f "${TEST_PLAYBOOK}" "${PROJECT_ROOT}/files/testing/test-inventory.yml"
    
    # Remove test image
    if podman image exists "${TEST_IMAGE}"; then
        podman rmi "${TEST_IMAGE}"
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                ;;
            --no-cleanup)
                CLEANUP=0
                ;;
            --image)
                shift
                TEST_IMAGE="$1"
                ;;
            --playbook)
                shift
                TEST_PLAYBOOK="$1"
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
}

# Main function
main() {
    parse_args "$@"
    local exit_code=0
    
    log_info "Starting end-to-end tests"
    
    # Setup
    run_environment_setup || exit_code=$?
    
    if [[ "${exit_code}" == "0" ]]; then
        # Build
        build_test_image || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        # Test
        create_test_playbook || exit_code=$?
        run_test_playbook || exit_code=$?
    fi
    
    # Cleanup (always attempt cleanup)
    cleanup_test_artifacts
    
    if [[ "${exit_code}" == "0" ]]; then
        log_info "End-to-end tests completed successfully"
    else
        log_error "End-to-end tests failed"
    fi
    
    return "${exit_code}"
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 