#!/bin/bash
set -ex

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Constants - ensure trailing slashes for API URLs
SSO_URL="https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token"
API_ROOT="https://console.redhat.com/api/automation-hub/"
CONTENT_PATH="content/published"
COLLECTION_VERSION="4.0.1"

# Function to validate JWT token
validate_token() {
    local token=$1
    local token_info
    token_info=$(echo "$token" | jq -R 'split(".") | .[1] | @base64d | fromjson' 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Invalid JWT token format${NC}"
        return 1
    fi

    local exp
    exp=$(echo "$token_info" | jq -r '.exp')
    local now
    now=$(date +%s)

    if [ "$exp" -lt "$now" ]; then
        echo -e "${RED}Token has expired${NC}"
        return 1
    fi

    # Validate token audience and issuer
    local aud
    aud=$(echo "$token_info" | jq -r '.aud | if type == "array" then .[0] else . end')
    local iss
    iss=$(echo "$token_info" | jq -r '.iss')

    if [[ "$iss" != "https://sso.redhat.com/auth/realms/redhat-external" ]]; then
        echo -e "${RED}Invalid token issuer${NC}"
        return 1
    fi

    if [[ "$aud" != "cloud-services" && "$aud" != "api.iam" ]]; then
        echo -e "${RED}Invalid token audience${NC}"
        return 1
    fi

    echo -e "${GREEN}Token is valid and not expired${NC}"
    echo "Token info:"
    echo "$token_info" | jq '.'
    return 0
}

# Function to test token against Automation Hub
test_automation_hub_access() {
    local token=$1
    
    echo "Testing access to Automation Hub API root..."
    local root_response
    root_response=$(curl -s -H "Authorization: Bearer $token" "$API_ROOT")
    
    if ! echo "$root_response" | jq -e '.available_versions' > /dev/null; then
        echo -e "${RED}Failed to access API root${NC}"
        echo "Response:"
        echo "$root_response" | jq '.'
        return 1
    fi
    echo -e "${GREEN}Successfully accessed API root${NC}"
    echo "Available versions:"
    echo "$root_response" | jq '.'
    
    # Get the v3 path from available versions
    local v3_path=$(echo "$root_response" | jq -r '.available_versions.v3')
    if [[ -z "$v3_path" || "$v3_path" == "null" ]]; then
        echo "Error: Could not find v3 API path in root response"
        echo "Raw response:"
        echo "$root_response"
        return 1
    fi

    echo "Using v3 API path: $v3_path"

    # Test access to published collections using v3 API
    local collections_url="${API_ROOT}${v3_path}plugin/ansible/content/published/collections/index/redhat/openshift/"
    echo "Testing access to collections repository..."
    echo "URL: $collections_url"

    local collections_response
    collections_response=$(curl -s -H "Authorization: Bearer $token" "$collections_url")
    echo "Response from collections API:"
    echo "$collections_response" | jq '.'

    if [[ $(echo "$collections_response" | jq -r 'if has("href") and has("highest_version") then "true" else "false" end') == "true" ]]; then
        echo "Successfully accessed collections repository"
        echo "Latest version available: $(echo "$collections_response" | jq -r '.highest_version.version')"
        
        # Now try to access the versions endpoint
        local versions_url="${API_ROOT}${v3_path}plugin/ansible/content/published/collections/index/redhat/openshift/versions/"
        echo -e "\nTesting access to collection versions..."
        echo "URL: $versions_url"
        
        local versions_response
        versions_response=$(curl -s -H "Authorization: Bearer $token" "$versions_url")
        echo "Response from versions API:"
        echo "$versions_response" | jq '.'
        
        if [[ $(echo "$versions_response" | jq -r 'if has("data") then "true" else "false" end') == "true" ]]; then
            echo "Successfully accessed collection versions"
            
            # Get version 4.0.1's href
            local version_href
            version_href=$(echo "$versions_response" | jq -r --arg version "$COLLECTION_VERSION" '.data[] | select(.version == $version) | .href')
            echo -e "\nGetting download URL for version $COLLECTION_VERSION..."
            
            # Get the version details
            local version_url="${API_ROOT}${version_href#/api/automation-hub/}"
            echo "Version URL: $version_url"
            local version_details
            version_details=$(curl -s -H "Authorization: Bearer $token" "$version_url")
            echo "Version details:"
            echo "$version_details" | jq '.'
            
            # Get the download URL from version details
            local download_url
            download_url=$(echo "$version_details" | jq -r '.download_url')
            
            if [[ -n "$download_url" && "$download_url" != "null" ]]; then
                # Remove any duplicate API root in the download URL
                if [[ "$download_url" == *"api/automation-hub/"* ]]; then
                    download_url="${API_ROOT}${download_url#*/api/automation-hub/}"
                fi
                echo -e "\nTesting access to collection download..."
                echo "Download URL: $download_url"
                
                # Try to download with automatic redirect following
                echo "Downloading collection to redhat-openshift-${COLLECTION_VERSION}.tar.gz..."
                local download_output
                download_output=$(curl -v -L -H "Authorization: Bearer $token" "$download_url" -o "redhat-openshift-${COLLECTION_VERSION}.tar.gz" 2>&1)
                if [ $? -eq 0 ] && [ -s "redhat-openshift-${COLLECTION_VERSION}.tar.gz" ]; then
                    echo -e "${GREEN}Successfully downloaded collection${NC}"
                    echo "Collection saved to: redhat-openshift-${COLLECTION_VERSION}.tar.gz"
                    ls -l "redhat-openshift-${COLLECTION_VERSION}.tar.gz"
                    file "redhat-openshift-${COLLECTION_VERSION}.tar.gz"
                else
                    echo -e "${RED}Failed to download collection${NC}"
                    echo "Download output:"
                    echo "$download_output"
                    echo "File content:"
                    cat "redhat-openshift-${COLLECTION_VERSION}.tar.gz"
                    return 1
                fi
                return 0
            else
                echo -e "${RED}Failed to get download URL from version details${NC}"
                return 1
            fi
        else
            echo "Failed to access collection versions"
            echo "Response status:"
            echo "$versions_response" | jq -r '.status // "No status in response"'
            echo "Response detail:"
            echo "$versions_response" | jq -r '.detail // "No detail in response"'
            return 1
        fi
    else
        echo "Failed to access collections repository"
        echo "Response status:"
        echo "$collections_response" | jq -r '.status // "No status in response"'
        echo "Response detail:"
        echo "$collections_response" | jq -r '.detail // "No detail in response"'
        echo "Failed to access Automation Hub with token"
        return 1
    fi
}

# Function to get access token from offline token
get_access_token() {
    local offline_token="$1"
    local sso_url="$2"
    
    if [[ -z "$offline_token" || -z "$sso_url" ]]; then
        echo "Error: offline_token and sso_url are required"
        return 1
    fi

    local response
    response=$(curl -s -X POST "$sso_url" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=refresh_token&client_id=cloud-services&refresh_token=$offline_token")

    local access_token
    access_token=$(echo "$response" | jq -r '.access_token')

    if [[ "$access_token" == "null" || -z "$access_token" ]]; then
        echo "Error: Failed to get access token"
        echo "Response: $response"
        return 1
    fi

    echo "$access_token"
}

echo -e "${YELLOW}Starting collection installation test...${NC}"

# Load environment variables from .env
if [ -f .env ]; then
    echo "Loading environment variables from .env"
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

echo -e "\n${YELLOW}1. Getting fresh access token...${NC}"
ACCESS_TOKEN=$(get_access_token "$OFFLINE_TOKEN" "$SSO_URL")
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to get access token${NC}"
    exit 1
fi

echo -e "\n${YELLOW}2. Validating access token...${NC}"
if ! validate_token "$ACCESS_TOKEN"; then
    echo -e "${RED}Access token validation failed${NC}"
    exit 1
fi

echo -e "\n${YELLOW}3. Testing Automation Hub access...${NC}"
if ! test_automation_hub_access "$ACCESS_TOKEN"; then
    echo -e "${RED}Failed to access Automation Hub${NC}"
    exit 1
fi

echo -e "\n${YELLOW}4. Setting up ansible configuration...${NC}"
# Create ansible.cfg with the access token
cat > ansible.cfg << EOL
[defaults]
collections_paths = ./collections

[galaxy]
server_list = automation_hub

[galaxy_server.automation_hub]
url = https://console.redhat.com/api/automation-hub/
token = $ACCESS_TOKEN
EOL

echo -e "${GREEN}Created ansible.cfg with access token${NC}"

echo -e "\n${YELLOW}5. Installing collection...${NC}"
if ! ANSIBLE_DEBUG=1 ansible-galaxy collection install redhat.openshift:${COLLECTION_VERSION} -vvv; then
    echo -e "${YELLOW}Installation from Automation Hub failed, attempting to install from downloaded tar file...${NC}"
    if [ -f "redhat-openshift-${COLLECTION_VERSION}.tar.gz" ]; then
        echo "Installing from local tar file: redhat-openshift-${COLLECTION_VERSION}.tar.gz"
        ANSIBLE_DEBUG=1 ansible-galaxy collection install "redhat-openshift-${COLLECTION_VERSION}.tar.gz" -vvv
    else
        echo -e "${RED}Local tar file not found: redhat-openshift-${COLLECTION_VERSION}.tar.gz${NC}"
        exit 1
    fi
fi

echo -e "\n${GREEN}Test complete!${NC}" 