#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Token refresh configuration
TOKEN_REFRESH_THRESHOLD=86400  # 24 hours in seconds
TOKEN_REFRESH_URL="https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token"

# Function to decode JWT and get expiration
get_token_expiration() {
    local token="$1"
    local payload
    
    # Extract payload (second part of JWT)
    payload=$(echo "$token" | cut -d. -f2)
    # Add padding if needed
    local pad=$(( 4 - ( ${#payload} % 4 ) ))
    if [[ $pad -ne 4 ]]; then
        payload="${payload}$(printf '=%.0s' $(seq 1 $pad))"
    fi
    
    # Decode payload and extract expiration
    local exp
    exp=$(echo "$payload" | base64 -d 2>/dev/null | jq -r '.exp')
    if [[ "$exp" =~ ^[0-9]+$ ]]; then
        echo "$exp"
        return 0
    fi
    return 1
}

# Function to check if token needs refresh
needs_refresh() {
    local token="$1"
    local exp
    local now
    
    exp=$(get_token_expiration "$token")
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to get token expiration${NC}"
        return 1
    fi
    
    now=$(date +%s)
    local time_left=$((exp - now))
    
    if [[ $time_left -lt $TOKEN_REFRESH_THRESHOLD ]]; then
        return 0  # Needs refresh
    fi
    return 1  # No refresh needed
}

# Function to refresh automation hub token
refresh_hub_token() {
    local current_token="$1"
    local refresh_token="$2"
    local client_id="$3"
    
    if [[ -z "$refresh_token" ]] || [[ -z "$client_id" ]]; then
        echo -e "${RED}Error: Refresh token and client ID are required${NC}"
        return 1
    fi
    
    # Attempt to refresh token
    local response
    response=$(curl -s -X POST "$TOKEN_REFRESH_URL" \
        -d "grant_type=refresh_token" \
        -d "refresh_token=$refresh_token" \
        -d "client_id=$client_id")
    
    if [[ "$response" == *"error"* ]] || [[ -z "$response" ]]; then
        echo -e "${RED}Failed to refresh token${NC}"
        return 1
    fi
    
    # Extract new access token
    local new_token
    new_token=$(echo "$response" | jq -r '.access_token')
    if [[ -z "$new_token" ]] || [[ "$new_token" == "null" ]]; then
        echo -e "${RED}Failed to extract new token${NC}"
        return 1
    fi
    
    # Validate new token format
    if [[ ! "$new_token" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
        echo -e "${RED}Invalid new token format${NC}"
        return 1
    fi
    
    # Update environment variable
    export ANSIBLE_HUB_TOKEN="$new_token"
    echo -e "${GREEN}Successfully refreshed Automation Hub token${NC}"
    
    # Return new token
    echo "$new_token"
    return 0
}

# Function to update token in environment file
update_env_file() {
    local new_token="$1"
    local env_file=".env"
    
    if [[ ! -f "$env_file" ]]; then
        echo -e "${RED}Error: .env file not found${NC}"
        return 1
    fi
    
    # Create backup
    cp "$env_file" "${env_file}.bak"
    
    # Update token in .env file
    sed -i.tmp "s|^ANSIBLE_HUB_TOKEN=.*|ANSIBLE_HUB_TOKEN=$new_token|" "$env_file"
    rm -f "${env_file}.tmp"
    
    echo -e "${GREEN}Updated token in $env_file${NC}"
    return 0
}

# Main function
main() {
    if [[ -z "$ANSIBLE_HUB_TOKEN" ]]; then
        echo -e "${RED}Error: ANSIBLE_HUB_TOKEN not set${NC}"
        exit 1
    fi
    
    # Check if token needs refresh
    if ! needs_refresh "$ANSIBLE_HUB_TOKEN"; then
        echo -e "${GREEN}Token is still valid, no refresh needed${NC}"
        exit 0
    fi
    
    echo "Token needs refresh, attempting to refresh..."
    
    # Refresh token using the offline token itself
    local new_token
    new_token=$(refresh_hub_token "$ANSIBLE_HUB_TOKEN" "$ANSIBLE_HUB_TOKEN" "cloud-services")
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to refresh token${NC}"
        exit 1
    fi
    
    # Update .env file
    if ! update_env_file "$new_token"; then
        echo -e "${YELLOW}Warning: Failed to update .env file${NC}"
    fi
    
    echo -e "${GREEN}Token refresh completed successfully${NC}"
    exit 0
}

# Run main function
main 