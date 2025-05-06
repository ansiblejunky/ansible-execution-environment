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
FORCE=0
REMOVE_VENV=1
REMOVE_CACHE=1
REMOVE_CONTAINERS=1
REMOVE_IMAGES=0

# Usage function
show_usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Clean up the Ansible Execution Environment development environment.

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -f, --force         Force cleanup without confirmation
    --keep-venv         Don't remove virtual environment
    --keep-cache        Don't remove cache files
    --keep-containers   Don't remove containers
    --remove-images     Also remove container images
EOF
}

# Function to confirm action
confirm_action() {
    local message="$1"
    
    if [[ "${FORCE}" == "1" ]]; then
        return 0
    fi
    
    read -r -p "${message} [y/N] " response
    case "${response}" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to cleanup Python environment
cleanup_python_env() {
    if [[ "${REMOVE_VENV}" != "1" ]]; then
        log_info "Skipping virtual environment cleanup"
        return 0
    fi
    
    log_info "Cleaning up Python environment"
    
    # Remove virtual environment
    if [[ -d "${PROJECT_ROOT}/.venv" ]]; then
        rm -rf "${PROJECT_ROOT}/.venv"
    fi
    
    # Remove pip cache
    if [[ "${REMOVE_CACHE}" == "1" ]]; then
        rm -rf "${HOME}/.cache/pip"
    fi
}

# Function to cleanup container environment
cleanup_container_env() {
    if [[ "${REMOVE_CONTAINERS}" != "1" ]]; then
        log_info "Skipping container cleanup"
        return 0
    fi
    
    log_info "Cleaning up container environment"
    
    # Stop and remove containers
    local containers
    containers=$(podman ps -a --format "{{.Names}}" | grep -E "^ansible-ee-|^ee-test-" || true)
    if [[ -n "${containers}" ]]; then
        echo "${containers}" | xargs -r podman rm -f
    fi
    
    # Remove images if requested
    if [[ "${REMOVE_IMAGES}" == "1" ]]; then
        local images
        images=$(podman images --format "{{.Repository}}:{{.Tag}}" | grep -E "^ansible-ee-|^ee-test-" || true)
        if [[ -n "${images}" ]]; then
            echo "${images}" | xargs -r podman rmi -f
        fi
    fi
}

# Function to cleanup build artifacts
cleanup_build_artifacts() {
    log_info "Cleaning up build artifacts"
    
    # Remove build directories
    local build_dirs=(
        "context"
        "collections"
        "dist"
        "build"
    )
    
    for dir in "${build_dirs[@]}"; do
        if [[ -d "${PROJECT_ROOT}/${dir}" ]]; then
            rm -rf "${PROJECT_ROOT:?}/${dir}"
        fi
    done
    
    # Remove temporary files
    find "${PROJECT_ROOT}" \
        -type f \( \
            -name "*.pyc" -o \
            -name "*.pyo" -o \
            -name "*.pyd" -o \
            -name "*.so" -o \
            -name "*.log" -o \
            -name "*.tmp" -o \
            -name "*.temp" \
        \) -delete
}

# Function to cleanup cache files
cleanup_cache_files() {
    if [[ "${REMOVE_CACHE}" != "1" ]]; then
        log_info "Skipping cache cleanup"
        return 0
    fi
    
    log_info "Cleaning up cache files"
    
    # Remove cache directories
    local cache_dirs=(
        ".cache"
        "__pycache__"
        ".pytest_cache"
        ".coverage"
    )
    
    for dir in "${cache_dirs[@]}"; do
        find "${PROJECT_ROOT}" -type d -name "${dir}" -exec rm -rf {} +
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
            -f|--force)
                FORCE=1
                ;;
            --keep-venv)
                REMOVE_VENV=0
                ;;
            --keep-cache)
                REMOVE_CACHE=0
                ;;
            --keep-containers)
                REMOVE_CONTAINERS=0
                ;;
            --remove-images)
                REMOVE_IMAGES=1
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
    
    log_info "Starting environment cleanup"
    
    # Confirm cleanup
    if ! confirm_action "This will clean up your development environment. Continue?"; then
        log_info "Cleanup cancelled"
        return 0
    fi
    
    # Run cleanup steps
    cleanup_python_env || exit_code=$?
    cleanup_container_env || exit_code=$?
    cleanup_build_artifacts || exit_code=$?
    cleanup_cache_files || exit_code=$?
    
    if [[ "${exit_code}" == "0" ]]; then
        log_info "Environment cleanup completed successfully"
    else
        log_error "Environment cleanup failed"
    fi
    
    return "${exit_code}"
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 