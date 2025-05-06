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
CHECK_ALL=1
CHECK_ENV=0
CHECK_DEPS=0
CHECK_CONFIG=0

# Required configuration files
REQUIRED_FILES=(
    "execution-environment.yml"
    "ansible-navigator.yml"
    "requirements.yml"
    "requirements.txt"
    "bindep.txt"
)

# Usage function
show_usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Validate the Ansible Execution Environment configuration and dependencies.

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --env-only          Only check environment setup
    --deps-only         Only check dependencies
    --config-only       Only check configuration files
EOF
}

# Function to validate environment setup
validate_environment() {
    log_info "Validating environment setup"
    
    # Check virtual environment
    if [[ ! -d "${PROJECT_ROOT}/.venv" ]]; then
        log_error "Virtual environment not found"
        return 1
    fi
    
    # Check environment variables
    local required_vars=(
        "ANSIBLE_HUB_TOKEN"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    log_info "Environment validation passed"
}

# Function to validate dependencies
validate_dependencies() {
    log_info "Validating dependencies"
    
    # Check Python packages
    if [[ -f "${PROJECT_ROOT}/requirements.txt" ]]; then
        log_info "Checking Python packages"
        if ! pip3 freeze | grep -q -f "${PROJECT_ROOT}/requirements.txt"; then
            log_error "Missing Python packages"
            return 1
        fi
    fi
    
    # Check Ansible collections
    if [[ -f "${PROJECT_ROOT}/requirements.yml" ]]; then
        log_info "Checking Ansible collections"
        if ! ansible-galaxy collection list | grep -q "ansible-automation-platform"; then
            log_error "Missing required Ansible collections"
            return 1
        fi
    fi
    
    log_info "Dependency validation passed"
}

# Function to validate configuration files
validate_configuration() {
    log_info "Validating configuration files"
    
    # Check required files exist
    local missing_files=()
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "${PROJECT_ROOT}/${file}" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing required files: ${missing_files[*]}"
        return 1
    fi
    
    # Validate YAML files
    if command -v yamllint >/dev/null 2>&1; then
        log_info "Validating YAML files"
        yamllint -c "${PROJECT_ROOT}/.yamllint.yml" "${PROJECT_ROOT}"/*.yml || {
            log_error "YAML validation failed"
            return 1
        }
    else
        log_warn "yamllint not found, skipping YAML validation"
    fi
    
    log_info "Configuration validation passed"
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
            --env-only)
                CHECK_ALL=0
                CHECK_ENV=1
                ;;
            --deps-only)
                CHECK_ALL=0
                CHECK_DEPS=1
                ;;
            --config-only)
                CHECK_ALL=0
                CHECK_CONFIG=1
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
    
    log_info "Starting validation checks"
    
    if [[ "${CHECK_ALL}" == "1" || "${CHECK_ENV}" == "1" ]]; then
        validate_environment || exit_code=$?
    fi
    
    if [[ "${CHECK_ALL}" == "1" || "${CHECK_DEPS}" == "1" ]]; then
        validate_dependencies || exit_code=$?
    fi
    
    if [[ "${CHECK_ALL}" == "1" || "${CHECK_CONFIG}" == "1" ]]; then
        validate_configuration || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        log_info "All validation checks passed"
    else
        log_error "Some validation checks failed"
    fi
    
    return "${exit_code}"
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 