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
AAP_URL="${AAP_URL:-}"
AAP_TOKEN="${AAP_TOKEN:-}"
AAP_VERIFY_SSL="${AAP_VERIFY_SSL:-true}"

# Usage function
show_usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Run AAP integration tests for the Ansible Execution Environment.

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --no-cleanup        Don't cleanup test artifacts
    --image NAME        Use specific test image (default: ${TEST_IMAGE})
    --aap-url URL      AAP controller URL
    --aap-token TOKEN  AAP authentication token
    --no-verify-ssl    Disable SSL verification for AAP
EOF
}

# Function to validate AAP connection
validate_aap_connection() {
    log_info "Validating AAP connection"
    
    # Check required variables
    if [[ -z "${AAP_URL}" || -z "${AAP_TOKEN}" ]]; then
        log_error "AAP_URL and AAP_TOKEN are required"
        return 1
    fi
    
    # Test AAP connection
    local verify_opt="--insecure"
    if [[ "${AAP_VERIFY_SSL}" == "true" ]]; then
        verify_opt=""
    fi
    
    curl ${verify_opt} -s \
        -H "Authorization: Bearer ${AAP_TOKEN}" \
        "${AAP_URL}/api/v2/ping/" | grep -q "OK" || {
        log_error "Failed to connect to AAP"
        return 1
    }
}

# Function to create test project
create_test_project() {
    log_info "Creating test project in AAP"
    
    local project_data='{
        "name": "ee-test-project",
        "description": "Test project for EE integration",
        "scm_type": "git",
        "scm_url": "https://github.com/ansible/test-playbooks.git"
    }'
    
    local verify_opt="--insecure"
    if [[ "${AAP_VERIFY_SSL}" == "true" ]]; then
        verify_opt=""
    fi
    
    curl ${verify_opt} -s \
        -H "Authorization: Bearer ${AAP_TOKEN}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "${project_data}" \
        "${AAP_URL}/api/v2/projects/" || {
        log_error "Failed to create test project"
        return 1
    }
}

# Function to create test inventory
create_test_inventory() {
    log_info "Creating test inventory in AAP"
    
    local inventory_data='{
        "name": "ee-test-inventory",
        "description": "Test inventory for EE integration"
    }'
    
    local verify_opt="--insecure"
    if [[ "${AAP_VERIFY_SSL}" == "true" ]]; then
        verify_opt=""
    fi
    
    curl ${verify_opt} -s \
        -H "Authorization: Bearer ${AAP_TOKEN}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "${inventory_data}" \
        "${AAP_URL}/api/v2/inventories/" || {
        log_error "Failed to create test inventory"
        return 1
    }
}

# Function to create test job template
create_test_job_template() {
    log_info "Creating test job template in AAP"
    
    local template_data='{
        "name": "ee-test-template",
        "description": "Test job template for EE integration",
        "job_type": "run",
        "inventory": "ee-test-inventory",
        "project": "ee-test-project",
        "playbook": "test.yml",
        "execution_environment": "'${TEST_IMAGE}'"
    }'
    
    local verify_opt="--insecure"
    if [[ "${AAP_VERIFY_SSL}" == "true" ]]; then
        verify_opt=""
    fi
    
    curl ${verify_opt} -s \
        -H "Authorization: Bearer ${AAP_TOKEN}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "${template_data}" \
        "${AAP_URL}/api/v2/job_templates/" || {
        log_error "Failed to create test job template"
        return 1
    }
}

# Function to run test job
run_test_job() {
    log_info "Running test job in AAP"
    
    local verify_opt="--insecure"
    if [[ "${AAP_VERIFY_SSL}" == "true" ]]; then
        verify_opt=""
    fi
    
    # Launch job
    local job_id
    job_id=$(curl ${verify_opt} -s \
        -H "Authorization: Bearer ${AAP_TOKEN}" \
        -X POST \
        "${AAP_URL}/api/v2/job_templates/ee-test-template/launch/" | jq -r '.id')
    
    # Wait for job completion
    local job_status
    while true; do
        job_status=$(curl ${verify_opt} -s \
            -H "Authorization: Bearer ${AAP_TOKEN}" \
            "${AAP_URL}/api/v2/jobs/${job_id}/" | jq -r '.status')
        
        if [[ "${job_status}" == "successful" ]]; then
            break
        elif [[ "${job_status}" == "failed" || "${job_status}" == "error" ]]; then
            log_error "Job failed with status: ${job_status}"
            return 1
        fi
        
        sleep 5
    done
}

# Function to cleanup test artifacts
cleanup_test_artifacts() {
    if [[ "${CLEANUP}" != "1" ]]; then
        log_info "Skipping cleanup as requested"
        return 0
    fi
    
    log_info "Cleaning up test artifacts"
    
    local verify_opt="--insecure"
    if [[ "${AAP_VERIFY_SSL}" == "true" ]]; then
        verify_opt=""
    fi
    
    # Delete test resources
    local resources=(
        "job_templates/ee-test-template"
        "projects/ee-test-project"
        "inventories/ee-test-inventory"
    )
    
    for resource in "${resources[@]}"; do
        curl ${verify_opt} -s \
            -H "Authorization: Bearer ${AAP_TOKEN}" \
            -X DELETE \
            "${AAP_URL}/api/v2/${resource}/" || true
    done
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
            --aap-url)
                shift
                AAP_URL="$1"
                ;;
            --aap-token)
                shift
                AAP_TOKEN="$1"
                ;;
            --no-verify-ssl)
                AAP_VERIFY_SSL="false"
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
    
    log_info "Starting AAP integration tests"
    
    # Run tests
    validate_aap_connection || exit_code=$?
    
    if [[ "${exit_code}" == "0" ]]; then
        create_test_project || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        create_test_inventory || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        create_test_job_template || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        run_test_job || exit_code=$?
    fi
    
    # Cleanup (always attempt cleanup)
    cleanup_test_artifacts
    
    if [[ "${exit_code}" == "0" ]]; then
        log_info "AAP integration tests completed successfully"
    else
        log_error "AAP integration tests failed"
    fi
    
    return "${exit_code}"
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 