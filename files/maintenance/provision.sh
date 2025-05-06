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
SYSTEM_PACKAGES=(
    "podman"
    "python3"
    "python3-pip"
    "python3-devel"
    "gcc"
    "git"
    "make"
    "curl"
    "jq"
)

# Usage function
show_usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Provision the system for Ansible Execution Environment development.

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -f, --force         Force installation even if already installed
EOF
}

# Function to detect OS
detect_os() {
    log_info "Detecting operating system"
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        OS_ID="${ID}"
        OS_VERSION_ID="${VERSION_ID}"
    else
        log_error "Unable to detect operating system"
        return 1
    fi
    
    log_info "Detected OS: ${OS_ID} ${OS_VERSION_ID}"
}

# Function to install system packages
install_system_packages() {
    log_info "Installing system packages"
    
    case "${OS_ID}" in
        rhel|centos)
            # Enable EPEL repository
            if ! rpm -q epel-release >/dev/null 2>&1; then
                log_info "Installing EPEL repository"
                sudo dnf install -y epel-release
            fi
            
            # Install packages
            sudo dnf install -y "${SYSTEM_PACKAGES[@]}"
            ;;
            
        fedora)
            sudo dnf install -y "${SYSTEM_PACKAGES[@]}"
            ;;
            
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y "${SYSTEM_PACKAGES[@]}"
            ;;
            
        *)
            log_error "Unsupported operating system: ${OS_ID}"
            return 1
            ;;
    esac
}

# Function to install Python tools
install_python_tools() {
    log_info "Installing Python tools"
    
    # Install/upgrade pip
    python3 -m pip install --upgrade pip
    
    # Install required Python packages
    python3 -m pip install --user \
        ansible-builder \
        ansible-navigator \
        yamllint
}

# Function to configure container environment
configure_container_env() {
    log_info "Configuring container environment"
    
    # Create container config directory
    local config_dir="${HOME}/.config/containers"
    mkdir -p "${config_dir}"
    
    # Configure container storage
    if [[ ! -f "${config_dir}/storage.conf" ]]; then
        cat > "${config_dir}/storage.conf" <<EOF
[storage]
driver = "overlay"
runroot = "/var/run/containers/storage"
graphroot = "/var/lib/containers/storage"
EOF
    fi
    
    # Configure container registries
    if [[ ! -f "${config_dir}/registries.conf" ]]; then
        cat > "${config_dir}/registries.conf" <<EOF
[[registry]]
location = "registry.redhat.io"
EOF
    fi
}

# Function to setup development environment
setup_dev_environment() {
    log_info "Setting up development environment"
    
    # Create workspace directory structure
    mkdir -p "${PROJECT_ROOT}"/{docs,files/{bootstrap,testing,maintenance}}
    
    # Initialize git repository if not already initialized
    if [[ ! -d "${PROJECT_ROOT}/.git" ]]; then
        git init "${PROJECT_ROOT}"
    fi
    
    # Create initial .gitignore if it doesn't exist
    if [[ ! -f "${PROJECT_ROOT}/.gitignore" ]]; then
        cat > "${PROJECT_ROOT}/.gitignore" <<EOF
# Python
__pycache__/
*.py[cod]
*.so
.Python
env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg
.venv/
venv/

# Environment
.env
*.env
*.token
*.key

# Temporary files
*.log
*.temp
*.tmp
temp/
.cache/

# Container artifacts
context/
collections/
EOF
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
            -f|--force)
                FORCE=1
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
    
    log_info "Starting system provisioning"
    
    # Run provisioning steps
    detect_os || exit_code=$?
    
    if [[ "${exit_code}" == "0" ]]; then
        install_system_packages || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        install_python_tools || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        configure_container_env || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        setup_dev_environment || exit_code=$?
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        log_info "System provisioning completed successfully"
    else
        log_error "System provisioning failed"
    fi
    
    return "${exit_code}"
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 