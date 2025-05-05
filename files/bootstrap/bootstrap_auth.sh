#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# DNS Resolvers for security
declare -A DNS_RESOLVERS=(
    ["cloudflare"]="1.1.1.1"
    ["google"]="8.8.8.8"
    ["quad9"]="9.9.9.9"
)

# Required domains
REQUIRED_DOMAINS=(
    "registry.redhat.io"
    "registry.connect.redhat.com"
)

# Function to validate email format
validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

# Function to validate JWT token format
validate_jwt() {
    local token="$1"
    # Check if token has three parts separated by dots
    if [[ ! "$token" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
        return 1
    fi
    
    # Decode and validate expiration if present
    local payload=$(echo "$token" | cut -d. -f2 | base64 -d 2>/dev/null)
    if [[ "$payload" == *"exp"* ]]; then
        local exp=$(echo "$payload" | jq -r '.exp')
        local now=$(date +%s)
        if [[ "$exp" -lt "$now" ]]; then
            echo "Token has expired"
            return 1
        fi
    fi
    
    return 0
}

# Function to validate registry credentials
validate_registry_auth() {
    local username="$1"
    local password="$2"
    
    # Check if username is email format
    if [[ "$username" == *"@"* ]]; then
        if ! validate_email "$username"; then
            echo -e "${RED}Invalid email format for registry username${NC}"
            return 1
        fi
    fi
    
    # Test authentication with registry
    if ! podman login --username "$username" --password "$password" registry.redhat.io >/dev/null 2>&1; then
        echo -e "${RED}Failed to authenticate with registry.redhat.io${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Registry authentication successful${NC}"
    return 0
}

# Function to validate automation hub token
validate_hub_token() {
    local token="$1"
    
    if ! validate_jwt "$token"; then
        echo -e "${RED}Invalid Automation Hub token format${NC}"
        return 1
    fi
    
    # Test token with automation hub API
    local api_response=$(curl -s -H "Authorization: Bearer $token" \
        https://console.redhat.com/api/automation-hub/v3/collections/ansible/ 2>/dev/null)
    
    if [[ "$api_response" == *"error"* ]] || [[ -z "$api_response" ]]; then
        echo -e "${RED}Failed to authenticate with Automation Hub${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Automation Hub token validation successful${NC}"
    return 0
}

# Function to validate DNS resolution
validate_dns() {
    local domain="$1"
    local resolved_ips=()
    local resolver_count=0
    local success_count=0
    
    for resolver in "${!DNS_RESOLVERS[@]}"; do
        local ip="${DNS_RESOLVERS[$resolver]}"
        ((resolver_count++))
        
        # Try resolving using specific DNS server
        local resolved=$(dig @"$ip" +short "$domain" 2>/dev/null)
        if [[ -n "$resolved" ]]; then
            resolved_ips+=("$resolved")
            ((success_count++))
        fi
    done
    
    # Check if we got consistent results from multiple resolvers
    if [[ "$success_count" -lt 2 ]]; then
        echo -e "${RED}DNS resolution failed for $domain${NC}"
        return 1
    fi
    
    # Verify PTR records
    for ip in "${resolved_ips[@]}"; do
        local ptr=$(dig @1.1.1.1 +short -x "$ip" 2>/dev/null)
        if [[ -z "$ptr" ]]; then
            echo -e "${YELLOW}Warning: No PTR record found for $ip${NC}"
        fi
    done
    
    echo -e "${GREEN}DNS validation successful for $domain${NC}"
    return 0
}

# Main validation function
main() {
    local has_error=0
    
    # Check required environment variables
    if [[ -z "$REGISTRY_USERNAME" ]] || [[ -z "$REGISTRY_PASSWORD" ]]; then
        echo -e "${RED}Error: REGISTRY_USERNAME and REGISTRY_PASSWORD must be set${NC}"
        has_error=1
    fi
    
    if [[ -z "$ANSIBLE_HUB_TOKEN" ]]; then
        echo -e "${RED}Error: ANSIBLE_HUB_TOKEN must be set${NC}"
        has_error=1
    fi
    
    # Exit early if environment variables are missing
    if [[ "$has_error" -eq 1 ]]; then
        exit 1
    fi
    
    # Validate DNS resolution for required domains
    echo "Validating DNS resolution..."
    for domain in "${REQUIRED_DOMAINS[@]}"; do
        if ! validate_dns "$domain"; then
            has_error=1
        fi
    done
    
    # Validate registry authentication
    echo "Validating registry authentication..."
    if ! validate_registry_auth "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD"; then
        has_error=1
    fi
    
    # Validate automation hub token
    echo "Validating Automation Hub token..."
    if ! validate_hub_token "$ANSIBLE_HUB_TOKEN"; then
        has_error=1
    fi
    
    if [[ "$has_error" -eq 1 ]]; then
        echo -e "${RED}Authentication validation failed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All authentication validations passed successfully${NC}"
    exit 0
}

# Run main function
main 