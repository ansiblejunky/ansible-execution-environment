#!/bin/bash
set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Constants for authentication and API endpoints
SSO_URL="https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token"
API_ROOT="https://console.redhat.com/api/automation-hub/"
CONTENT_PATH="content/published"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions with security considerations
log_info() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_debug() { [[ "${VERBOSE:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
log_secure() { echo -e "${GREEN}[SECURE]${NC} Operation completed" >&2; }

# Enhanced error handling
trap 'handle_error $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

handle_error() {
    local exit_code=$1
    local line_no=$2
    local bash_lineno=$3
    local last_command=$4
    local func_trace=$5
    log_error "Error in ${SCRIPT_NAME}: Command '$last_command' exited with status $exit_code"
    log_error "Line: $line_no"
    log_error "Function trace: $func_trace"
    exit "$exit_code"
}

# Default values
VERBOSE=0
FORCE=0
SKIP_DEPS=0

# Required tools
REQUIRED_TOOLS=(
    "podman"
    "ansible-builder"
    "ansible-navigator"
    "python3"
    "pip3"
    "dig"  # Required for DNS checks
)

# Required Red Hat domains
REQUIRED_DOMAINS=(
    "registry.redhat.io"
    "registry.connect.redhat.com"
)

# Enhanced token validation function
validate_token() {
    local token_type="$1"
    local token="$2"
    
    case "$token_type" in
        "hub")
            # Basic validation - token should not be empty
            if [[ -z "$token" ]]; then
                log_error "Empty token provided"
                return 1
            fi
            
            # Check if it's a JWT token (contains at least one dot)
            if [[ ! "$token" =~ \. ]]; then
                log_warn "Token does not appear to be in JWT format"
                # Don't fail on this
            fi
            
            # Validate basic token format - allow more characters
            if [[ ! "$token" =~ ^[A-Za-z0-9._+/=-]+$ ]]; then
                log_error "Token contains invalid characters"
                return 1
            fi
            
            # If it looks like a JWT, validate its structure
            if [[ "$token" =~ \. ]]; then
                local jwt_parts
                IFS='.' read -ra jwt_parts <<< "$token"
                
                # Warn but don't fail if not exactly 3 parts
                if [[ "${#jwt_parts[@]}" != 3 ]]; then
                    log_warn "JWT token does not have the standard 3 parts"
                    # Don't fail on this
                fi
                
                # Try to validate expiry if possible
                if [[ "${#jwt_parts[@]}" -ge 2 ]]; then
                    local payload
                    if payload=$(echo "${jwt_parts[1]}" | base64 -d 2>/dev/null); then
                        local exp
                        exp=$(echo "$payload" | jq -r '.exp // empty' 2>/dev/null)
                        if [[ -n "$exp" && "$exp" -lt $(date +%s) ]]; then
                            log_warn "Token appears to be expired"
                            # Don't fail on this - let the API handle it
                        fi
                    fi
                fi
            fi
            ;;
        "registry")
            # Validate Registry Service Account credentials
            # Allow both username/password and email/password formats
            local username="$2"
            if [[ ! "$username" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ && ! "$username" =~ ^[A-Za-z0-9_-]{3,}$ ]]; then
                log_error "Invalid username format"
                return 1
            fi
            ;;
        *)
            log_error "Unknown token type: $token_type"
            return 1
            ;;
    esac
    
    return 0
}

# Token refresh function with improved security and automation
refresh_token() {
    local token_type="$1"
    local current_token="$2"
    
    case "$token_type" in
        "hub")
            log_info "Attempting to refresh Automation Hub token"
            local response
            # Use secure curl options as per ADR
            response=$(curl "https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token" \
                -d "grant_type=refresh_token" \
                -d "client_id=cloud-services" \
                -d "refresh_token=${current_token}" \
                --fail \
                --silent \
                --show-error \
                --write-out "%{http_code}" \
                2>/dev/null)
            
            local status_code="${response: -3}"
            local response_body="${response:0:-3}"
            
            if [[ "$status_code" == "200" ]]; then
                local new_token
                new_token=$(echo "$response_body" | jq -r '.access_token // empty')
                if [[ -n "$new_token" && "$new_token" != "null" ]]; then
                    log_info "Token refreshed successfully"
                    # Update the environment variable
                    export ANSIBLE_HUB_TOKEN="$new_token"
                    # Update .env file if it exists
                    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
                        # Create a temporary file with updated token
                        sed "s|^ANSIBLE_HUB_TOKEN=.*|ANSIBLE_HUB_TOKEN=${new_token}|" "${PROJECT_ROOT}/.env" > "${PROJECT_ROOT}/.env.tmp"
                        # Securely replace the original file
                        mv "${PROJECT_ROOT}/.env.tmp" "${PROJECT_ROOT}/.env"
                        chmod 600 "${PROJECT_ROOT}/.env"
                    fi
                    return 0
                fi
            fi
            
            log_error "Failed to refresh token (HTTP ${status_code})"
            if [[ -n "$response_body" ]]; then
                local error_msg
                error_msg=$(echo "$response_body" | jq -r '.error_description // .error // "Unknown error"')
                log_error "Error: $error_msg"
            fi
            return 1
            ;;
        *)
            log_error "Token refresh not implemented for type: $token_type"
            return 1
            ;;
    esac
}

# Function to check if token needs refresh
check_token_expiry() {
    local token="$1"
    local jwt_parts
    
    IFS='.' read -ra jwt_parts <<< "$token"
    if [[ "${#jwt_parts[@]}" -ge 2 ]]; then
        local payload
        if payload=$(echo "${jwt_parts[1]}" | base64 -d 2>/dev/null); then
            local exp
            exp=$(echo "$payload" | jq -r '.exp // empty' 2>/dev/null)
            if [[ -n "$exp" ]]; then
                local now
                now=$(date +%s)
                local threshold=$((now + 86400)) # Refresh if expires within 24 hours
                
                if [[ "$exp" -lt "$now" ]]; then
                    log_error "Token has expired"
                    return 1
                elif [[ "$exp" -lt "$threshold" ]]; then
                    log_warn "Token will expire soon, refreshing"
                    return 2
                fi
            fi
        fi
    fi
    return 0
}

# Function to get access token from offline token
get_access_token() {
    local offline_token=$1
    
    log_info "Requesting access token from SSO"
    local response
    response=$(curl -s -X POST "https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=refresh_token" \
        -d "client_id=cloud-services" \
        -d "refresh_token=$offline_token" \
        --fail \
        --show-error \
        2>&1)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to get access token"
        log_error "Error: $response"
        return 1
    fi
    
    local access_token
    access_token=$(echo "$response" | jq -r '.access_token')
    
    if [[ "$access_token" == "null" || -z "$access_token" ]]; then
        log_error "Failed to get access token"
        echo "$response" | jq -r '.error_description // .error // "Unknown error"' >&2
        return 1
    fi
    
    echo "$access_token"
}

# Function to validate DNS resolution with enhanced checks
validate_dns() {
    local domain=$1
    log_info "Validating DNS resolution for $domain"
    
    # Check primary DNS
    local primary_ip
    primary_ip=$(dig +short "@1.1.1.1" "$domain" | head -n1)
    if [[ -z "$primary_ip" ]]; then
        log_error "Primary DNS resolution failed for $domain"
        return 1
    fi
    
    # Check secondary DNS
    local secondary_ip
    secondary_ip=$(dig +short "@8.8.8.8" "$domain" | head -n1)
    if [[ -z "$secondary_ip" ]]; then
        log_error "Secondary DNS resolution failed for $domain"
        return 1
    fi
    
    # Compare results
    if [[ "$primary_ip" != "$secondary_ip" ]]; then
        log_warn "DNS resolution mismatch for $domain"
        log_warn "Primary: $primary_ip"
        log_warn "Secondary: $secondary_ip"
    fi
    
    # Verify connectivity
    if ! curl -s -m 5 -o /dev/null "https://$domain"; then
        log_error "Cannot establish connection to $domain"
        return 1
    fi
    
    log_debug "Resolved IP for $domain: $primary_ip"
    return 0
}

# Enhanced environment variable validation
validate_env() {
    local required_vars=(
        "ANSIBLE_HUB_TOKEN"
        "REGISTRY_USERNAME"
        "REGISTRY_PASSWORD"
    )
    
    # Check if .env file exists and source it
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        log_info "Loading environment variables from .env"
        # shellcheck disable=SC1091
        source "${PROJECT_ROOT}/.env"
    elif [[ -f "${PROJECT_ROOT}/.env-example" ]]; then
        log_warn "No .env file found, but .env-example exists"
        log_info "Please copy .env-example to .env and configure it"
    fi
    
    # Validate required environment variables
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        exit 1
    fi
    
    # Check token expiry and refresh if needed
    local token_status
    check_token_expiry "$ANSIBLE_HUB_TOKEN"
    token_status=$?
    
    if [[ "$token_status" -eq 1 ]]; then
        log_error "Token has expired, attempting refresh"
        if ! refresh_token "hub" "$ANSIBLE_HUB_TOKEN"; then
            log_error "Failed to refresh expired token"
            exit 1
        fi
    elif [[ "$token_status" -eq 2 ]]; then
        log_info "Token will expire soon, refreshing"
        if ! refresh_token "hub" "$ANSIBLE_HUB_TOKEN"; then
            log_warn "Failed to refresh token, but continuing with current token"
        fi
    fi
    
    # Validate token formats
    if ! validate_token "hub" "$ANSIBLE_HUB_TOKEN"; then
        log_error "Invalid ANSIBLE_HUB_TOKEN format"
        exit 1
    fi
    
    # Validate username format
    if [[ ! "${REGISTRY_USERNAME}" =~ ^[a-zA-Z0-9.@_-]+$ ]]; then
        log_error "Invalid REGISTRY_USERNAME format"
        exit 1
    fi
    
    log_secure
}

# Function to download collections locally
download_collections() {
    local token="$1"
    log_info "Checking for collections to download"
    
    # Create collections directory if it doesn't exist
    local collections_dir="${PROJECT_ROOT}/collections"
    mkdir -p "$collections_dir"
    
    # First get API version info
    log_info "Getting API version info"
    local root_response
    root_response=$(curl -s -H "Authorization: Bearer $token" "https://console.redhat.com/api/automation-hub/")
    
    local v3_path
    v3_path=$(echo "$root_response" | jq -r '.available_versions.v3')
    if [[ -z "$v3_path" || "$v3_path" == "null" ]]; then
        log_error "Could not determine API version path"
        return 1
    fi
    log_info "Using API path: $v3_path"
    
    # Ensure proper URL construction with correct slashes
    local base_url="https://console.redhat.com/api/automation-hub"
    # Remove leading/trailing slashes from v3_path to ensure clean URL construction
    v3_path="${v3_path#/}"
    v3_path="${v3_path%/}"
    
    # Get collection info - list available versions
    local collections_url="${base_url}/${v3_path}/plugin/ansible/content/published/collections/index/redhat/openshift/versions/"
    log_info "Getting collection versions from: $collections_url"
    
    local versions_response
    versions_response=$(curl -s -H "Authorization: Bearer $token" "$collections_url")
    
    # Debug output to see what we're getting back
    log_debug "API Response: $versions_response"
    
    # Get the three most recent versions
    local version_hrefs
    version_hrefs=$(echo "$versions_response" | jq -r '.data | sort_by(.version) | reverse | .[0:3] | .[].href // empty')
    
    if [[ -z "$version_hrefs" ]]; then
        log_error "No versions found"
        log_error "API Response: $versions_response"
        return 1
    fi
    
    local success_count=0
    local fail_count=0
    
    # Process each version
    while IFS= read -r version_href; do
        # Get version details
        local version_url="${base_url}${version_href#/api/automation-hub}"
        log_info "Getting version details from: $version_url"
        
        local version_details
        version_details=$(curl -s -H "Authorization: Bearer $token" "$version_url")
        
        # Get download URL and version
        local download_url
        download_url=$(echo "$version_details" | jq -r '.download_url')
        local collection_version
        collection_version=$(echo "$version_details" | jq -r '.version')
        
        if [[ -z "$download_url" || "$download_url" == "null" ]]; then
            log_error "Could not get download URL for version $collection_version"
            ((fail_count++))
            continue
        fi
        
        # Clean up URL if needed
        if [[ "$download_url" == *"api/automation-hub/"* ]]; then
            download_url="${base_url}/${download_url#*/api/automation-hub/}"
        fi
        
        log_info "Downloading version $collection_version from: $download_url"
        local target_file="${collections_dir}/redhat-openshift-${collection_version}.tar.gz"
        
        if curl -s -L -H "Authorization: Bearer $token" "$download_url" -o "$target_file" --fail --show-error; then
            log_info "Successfully downloaded redhat.openshift:${collection_version}"
            chmod 644 "$target_file"
            ((success_count++))
        else
            log_error "Failed to download redhat.openshift:${collection_version}"
            rm -f "$target_file"  # Clean up failed download
            ((fail_count++))
        fi
    done <<< "$version_hrefs"
    
    # Report results
    log_info "Download summary: $success_count successful, $fail_count failed"
    
    if [[ $success_count -eq 0 ]]; then
        log_error "Failed to download any collections"
        return 1
    fi
    
    return 0
}

# Update setup_container_env to use local collections
setup_container_env() {
    log_info "Validating container environment"
    
    # Validate DNS resolution for required domains
    for domain in "${REQUIRED_DOMAINS[@]}"; do
        if ! validate_dns "$domain"; then
            log_error "DNS validation failed for $domain"
            exit 1
        fi
    done
    
    # Test podman access
    if ! podman info >/dev/null 2>&1; then
        log_error "Unable to access podman. Please ensure it's properly configured"
        exit 1
    fi
    
    # Get fresh access token for Automation Hub
    log_info "Getting fresh access token for Automation Hub"
    local access_token
    if ! access_token=$(get_access_token "$ANSIBLE_HUB_TOKEN"); then
        log_error "Failed to get access token for Automation Hub"
        exit 1
    fi
    
    # Download collections locally
    if ! download_collections "$access_token"; then
        log_error "Failed to download required collections"
        exit 1
    fi
    
    # Login to registries with enhanced error handling
    log_info "Logging into container registries"
    
    # Login to registry.redhat.io
    if ! echo "${REGISTRY_PASSWORD}" | podman login registry.redhat.io --username "${REGISTRY_USERNAME}" --password-stdin; then
        log_error "Failed to login to registry.redhat.io"
        log_info "Verifying registry.redhat.io accessibility..."
        curl -sL https://registry.redhat.io/v2/ >/dev/null || log_error "Cannot access registry API"
        exit 1
    fi
    
    # Login to registry.connect.redhat.com using the same credentials as registry.redhat.io
    if ! echo "${REGISTRY_PASSWORD}" | podman login registry.connect.redhat.com --username "${REGISTRY_USERNAME}" --password-stdin; then
        log_error "Failed to login to registry.connect.redhat.com"
        log_info "Note: registry.connect.redhat.com uses the same credentials as registry.redhat.io"
        exit 1
    fi
    
    log_secure
}

# Usage function
show_usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Bootstrap the Ansible Execution Environment development environment.

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -f, --force         Force setup even if already initialized
    --skip-deps         Skip dependency installation
EOF
}

# Function to check if a command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install a tool
install_tool() {
    local tool=$1
    log_info "Attempting to install $tool"
    
    case $tool in
        podman)
            sudo dnf install -y podman
            ;;
        ansible-builder|ansible-navigator)
            pip3 install --user "$tool"
            ;;
        python3)
            sudo dnf install -y python3
            ;;
        pip3)
            sudo dnf install -y python3-pip
            ;;
        *)
            log_error "Don't know how to install $tool"
            return 1
            ;;
    esac
}

# Function to check required tools
check_required_tools() {
    local missing_tools=()
    local failed_installs=()
    
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! check_command "$tool"; then
            log_warn "Missing required tool: $tool"
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_info "Attempting to install missing tools"
        for tool in "${missing_tools[@]}"; do
            if ! install_tool "$tool"; then
                failed_installs+=("$tool")
            fi
        done
    fi
    
    if [[ ${#failed_installs[@]} -gt 0 ]]; then
        log_error "Failed to install tools: ${failed_installs[*]}"
        log_info "Please install these tools manually and try again"
        exit 1
    fi
}

# Function to setup Python virtual environment
setup_venv() {
    if [[ -d "${PROJECT_ROOT}/.venv" && "${FORCE}" != "1" ]]; then
        log_info "Virtual environment already exists"
        return 0
    fi

    log_info "Setting up Python virtual environment"
    python3 -m venv "${PROJECT_ROOT}/.venv"
    source "${PROJECT_ROOT}/.venv/bin/activate"
    pip3 install --upgrade pip
    
    if [[ -f "${PROJECT_ROOT}/requirements.txt" ]]; then
        log_info "Installing Python dependencies"
        pip3 install -r "${PROJECT_ROOT}/requirements.txt"
    fi
}

# Function to setup Ansible collections
setup_ansible_collections() {
    if [[ -f "${PROJECT_ROOT}/requirements.yml" ]]; then
        log_info "Installing Ansible collections"
        ansible-galaxy collection install -r "${PROJECT_ROOT}/requirements.yml"
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
            --skip-deps)
                SKIP_DEPS=1
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
    
    log_info "Starting environment bootstrap"
    
    # Check required tools
    check_required_tools
    
    # Setup steps
    validate_env
    
    if [[ "${SKIP_DEPS}" != "1" ]]; then
        setup_venv
        setup_ansible_collections
    fi
    
    setup_container_env
    
    log_info "Environment bootstrap complete"
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 