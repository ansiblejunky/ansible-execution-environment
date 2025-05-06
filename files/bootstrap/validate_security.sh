#!/bin/bash
set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Import common functions
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/bootstrap_env.sh"

# Validation categories
declare -A VALIDATION_CATEGORIES=(
    ["dns"]="DNS Resolution Checks"
    ["token"]="Token Validation"
    ["security"]="Security Controls"
    ["compliance"]="Compliance Requirements"
)

# Function to validate DNS security
validate_dns_security() {
    local status=0
    log_info "Performing DNS security validation"
    
    # DNS resolvers to check against
    local -a DNS_RESOLVERS=(
        "1.1.1.1"    # Cloudflare
        "8.8.8.8"    # Google
        "9.9.9.9"    # Quad9
    )
    
    # Check each required domain
    for domain in "${REQUIRED_DOMAINS[@]}"; do
        log_info "Validating DNS for $domain"
        
        # Test connectivity to DNS resolvers first
        local available_resolvers=()
        for resolver in "${DNS_RESOLVERS[@]}"; do
            if ping -c 1 -W 2 "$resolver" >/dev/null 2>&1; then
                available_resolvers+=("$resolver")
            else
                log_warn "DNS resolver $resolver is not reachable"
            fi
        done
        
        if [[ ${#available_resolvers[@]} -lt 2 ]]; then
            log_error "Not enough DNS resolvers available for cross-validation"
            status=1
            continue
        fi
        
        # Store resolutions from each resolver
        declare -A resolutions
        local resolution_count=0
        for resolver in "${available_resolvers[@]}"; do
            local ips
            if ! ips=$(dig +short "@$resolver" "$domain" +timeout=5 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort); then
                log_error "DNS resolution failed using resolver $resolver"
                status=1
                continue
            fi
            
            if [[ -z "$ips" ]]; then
                log_error "No valid IP addresses returned for $domain using resolver $resolver"
                status=1
                continue
            fi
            
            resolutions["$resolver"]="$ips"
            ((resolution_count++))
        done
        
        # Compare resolutions
        if [[ $resolution_count -ge 2 ]]; then
            local first_resolver="${available_resolvers[0]}"
            local first_resolution="${resolutions[$first_resolver]}"
            
            for ((i=1; i<${#available_resolvers[@]}; i++)); do
                local current_resolver="${available_resolvers[$i]}"
                local current_resolution="${resolutions[$current_resolver]}"
                
                if [[ "$first_resolution" != "$current_resolution" ]]; then
                    log_error "DNS resolution mismatch for $domain"
                    log_error "Resolution from $first_resolver:"
                    echo "$first_resolution" | sed 's/^/    /'
                    log_error "Resolution from $current_resolver:"
                    echo "$current_resolution" | sed 's/^/    /'
                    status=1
                    break
                fi
            done
        else
            log_error "Insufficient successful DNS resolutions for $domain"
            status=1
        fi
        
        # Verify reverse DNS (PTR) records
        if [[ $status -eq 0 ]]; then
            local first_ip
            first_ip=$(echo "${resolutions[${available_resolvers[0]}]}" | head -n1)
            local ptr_record
            if ! ptr_record=$(dig +short -x "$first_ip" 2>/dev/null); then
                log_warn "Unable to verify reverse DNS for $first_ip"
            else
                log_info "Reverse DNS for $domain: $ptr_record"
            fi
        fi
    done
    
    return $status
}

# Function to validate token security
validate_token_security() {
    local status=0
    log_info "Performing token security validation"
    
    # Check token storage
    if grep -r "ANSIBLE_HUB_TOKEN\|REGISTRY_PASSWORD" "${PROJECT_ROOT}" --exclude-dir=".git" | grep -v "\.env"; then
        log_error "Found potential hardcoded credentials"
        status=1
    fi
    
    # Validate token formats
    if ! validate_token "hub" "${ANSIBLE_HUB_TOKEN:-}"; then
        log_error "Invalid hub token format"
        status=1
    fi
    
    # Check file permissions
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        local env_perms
        env_perms=$(stat -c "%a" "${PROJECT_ROOT}/.env")
        if [[ "$env_perms" != "600" ]]; then
            log_error ".env file has incorrect permissions: $env_perms (should be 600)"
            status=1
        fi
    fi
    
    return $status
}

# Function to validate security controls
validate_security_controls() {
    local status=0
    log_info "Validating security controls"
    
    # Check script permissions
    local script_perms
    script_perms=$(stat -c "%a" "${SCRIPT_DIR}/bootstrap_env.sh")
    if [[ "$script_perms" != "755" ]]; then
        log_error "bootstrap_env.sh has incorrect permissions: $script_perms (should be 755)"
        status=1
    fi
    
    # Check for sensitive data in logs
    if find "${PROJECT_ROOT}" -type f -name "*.log" -exec grep -l "token\|password\|secret" {} \;; then
        log_error "Found potential sensitive data in log files"
        status=1
    fi
    
    # Validate TLS configuration
    if ! curl -sL --tlsv1.2 https://registry.redhat.io/v2/ >/dev/null; then
        log_error "TLS 1.2 connection failed to registry.redhat.io"
        status=1
    fi
    
    return $status
}

# Function to validate compliance requirements
validate_compliance() {
    local status=0
    log_info "Validating compliance requirements"
    
    # Check logging configuration
    if [[ ! -d "${PROJECT_ROOT}/logs" ]]; then
        log_error "Logging directory not found"
        status=1
    fi
    
    # Verify audit logging
    if [[ ! -f "${PROJECT_ROOT}/logs/audit.log" ]]; then
        log_error "Audit log file not found"
        status=1
    fi
    
    # Check for required security headers
    local security_headers
    security_headers=$(curl -sI https://registry.redhat.io | grep -i 'strict-transport-security\|x-content-type-options\|x-frame-options')
    if [[ -z "$security_headers" ]]; then
        log_warn "Missing recommended security headers in registry response"
    fi
    
    return $status
}

# Main validation function
main() {
    local exit_status=0
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Run all validations
    for category in "${!VALIDATION_CATEGORIES[@]}"; do
        log_info "Running ${VALIDATION_CATEGORIES[$category]}"
        if ! "validate_${category}"; then
            exit_status=1
        fi
    done
    
    if [[ $exit_status -eq 0 ]]; then
        log_info "All security validations passed"
    else
        log_error "Some security validations failed"
    fi
    
    return $exit_status
}

# Show usage information
show_usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Validate security and compliance requirements for the Ansible Execution Environment.

Options:
    -h, --help     Show this help message
    -v, --verbose  Enable verbose output

Validation Categories:
$(for category in "${!VALIDATION_CATEGORIES[@]}"; do echo "    - ${VALIDATION_CATEGORIES[$category]}"; done)
EOF
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 