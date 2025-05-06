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
TEST_CONTAINER="ansible-ee-test-container"

# Usage function
show_usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Run container tests for the Ansible Execution Environment.

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --no-cleanup        Don't cleanup test container
    --image NAME        Use specific test image (default: ${TEST_IMAGE})
EOF
}

# Function to check container runtime
check_container_runtime() {
    log_info "Checking container runtime"
    
    if ! command -v podman >/dev/null 2>&1; then
        log_error "Podman is required but not installed"
        return 1
    fi
    
    if ! podman info >/dev/null 2>&1; then
        log_error "Unable to access podman. Please ensure it's properly configured"
        return 1
    }
}

# Function to pull base image
pull_base_image() {
    log_info "Pulling base image"
    
    podman pull registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest || {
        log_error "Failed to pull base image"
        return 1
    }
}

# Function to test container creation
test_container_creation() {
    log_info "Testing container creation"
    
    # Remove existing container if it exists
    if podman container exists "${TEST_CONTAINER}"; then
        podman rm -f "${TEST_CONTAINER}"
    fi
    
    # Create container
    podman run --name "${TEST_CONTAINER}" \
        -d \
        --rm \
        "${TEST_IMAGE}" \
        sleep infinity || {
        log_error "Failed to create container"
        return 1
    }
}

# Function to test container commands
test_container_commands() {
    log_info "Testing container commands"
    
    # Test commands
    local commands=(
        "python3 --version"
        "ansible --version"
        "ansible-galaxy collection list"
        "pip3 list"
    )
    
    for cmd in "${commands[@]}"; do
        log_info "Testing command: ${cmd}"
        if ! podman exec "${TEST_CONTAINER}" bash -c "${cmd}"; then
            log_error "Command failed: ${cmd}"
            return 1
        fi
    done
}

# Function to test container environment
test_container_environment() {
    log_info "Testing container environment"
    
    # Create test script
    local test_script="/tmp/test-env.sh"
    cat > "${test_script}" <<'EOF'
#!/bin/bash
set -euo pipefail

# Test Python environment
python3 -c "import sys; assert sys.version_info >= (3, 9), 'Python version must be >= 3.9'"

# Test Ansible environment
ansible --version | grep -q "core.*2\." || exit 1

# Test package installation
pip3 list | grep -q "ansible" || exit 1

# Test collection installation
ansible-galaxy collection list | grep -q "ansible-automation-platform" || exit 1
EOF
    
    # Copy and execute test script in container
    podman cp "${test_script}" "${TEST_CONTAINER}:/tmp/test-env.sh"
    podman exec "${TEST_CONTAINER}" chmod +x /tmp/test-env.sh
    
    if ! podman exec "${TEST_CONTAINER}" /tmp/test-env.sh; then
        log_error "Container environment tests failed"
        return 1
    fi
    
    rm -f "${test_script}"
}

# Function to cleanup test artifacts
cleanup_test_artifacts() {
    if [[ "${CLEANUP}" != "1" ]]; then
        log_info "Skipping cleanup as requested"
        return 0
    fi
    
    log_info "Cleaning up test artifacts"
    
    # Stop and remove test container
    if podman container exists "${TEST_CONTAINER}"; then
        podman stop "${TEST_CONTAINER}"
        podman rm -f "${TEST_CONTAINER}"
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
    
    log_info "Starting container tests"
    
    # Run tests
    check_container_runtime || exit_code=$?
    
    if [[ "${exit_code}" == "0" ]]; then
        pull_base_image || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        test_container_creation || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        test_container_commands || exit_code=$?
        test_container_environment || exit_code=$?
    fi
    
    # Cleanup (always attempt cleanup)
    cleanup_test_artifacts
    
    if [[ "${exit_code}" == "0" ]]; then
        log_info "Container tests completed successfully"
    else
        log_error "Container tests failed"
    fi
    
    return "${exit_code}"
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 