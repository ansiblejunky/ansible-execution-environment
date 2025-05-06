#!/bin/bash

# Automated verification script for execution environment examples
# This script performs basic validation and testing of example configurations

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
EXAMPLE_FILE=""
VERBOSE=false

# Help message
usage() {
    echo "Usage: $0 -e <example_file> [-v]"
    echo "  -e: Path to example file to verify"
    echo "  -v: Verbose output"
    exit 1
}

# Parse arguments
while getopts "e:v" opt; do
    case $opt in
        e) EXAMPLE_FILE="$OPTARG" ;;
        v) VERBOSE=true ;;
        *) usage ;;
    esac
done

if [ -z "$EXAMPLE_FILE" ]; then
    usage
fi

log() {
    local level=$1
    shift
    case $level in
        INFO) echo -e "${GREEN}[INFO]${NC} $*" ;;
        WARN) echo -e "${YELLOW}[WARN]${NC} $*" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $*" ;;
    esac
}

# Check 1: YAML Syntax
check_yaml_syntax() {
    log INFO "Checking YAML syntax for $EXAMPLE_FILE"
    if ! yamllint -d relaxed "$EXAMPLE_FILE"; then
        log ERROR "YAML syntax check failed"
        return 1
    fi
    log INFO "YAML syntax check passed"
}

# Check 2: Required Fields
check_required_fields() {
    log INFO "Checking required fields"
    local missing=false
    
    # Use yq to check for required fields
    for field in "base_image.name" "dependencies" "package_manager.path"; do
        if ! yq eval ".$field" "$EXAMPLE_FILE" > /dev/null 2>&1; then
            log ERROR "Missing required field: $field"
            missing=true
        fi
    done
    
    if [ "$missing" = true ]; then
        return 1
    fi
    log INFO "Required fields check passed"
}

# Check 3: Dependencies Version Check
check_dependencies() {
    log INFO "Checking dependencies"
    
    # Check Python requirements
    if [ -f "$(dirname "$EXAMPLE_FILE")/../files/requirements.txt" ]; then
        log INFO "Validating Python requirements"
        if ! pip check > /dev/null 2>&1; then
            log ERROR "Python dependencies have conflicts"
            return 1
        fi
    fi
    
    # Check system packages
    if [ -f "$(dirname "$EXAMPLE_FILE")/../files/bindep.txt" ]; then
        log INFO "Validating system dependencies"
        if ! bindep -b > /dev/null 2>&1; then
            log WARN "Some system dependencies may be missing"
        fi
    fi
    
    log INFO "Dependencies check passed"
}

# Check 4: Verification Header
check_verification_header() {
    log INFO "Checking verification header"
    
    if ! grep -q "Last Verified:" "$EXAMPLE_FILE"; then
        log ERROR "Missing verification header"
        return 1
    fi
    
    if ! grep -q "Status:" "$EXAMPLE_FILE"; then
        log ERROR "Missing verification status"
        return 1
    fi
    
    log INFO "Verification header check passed"
}

# Check 5: Build Test
test_build() {
    log INFO "Testing example build"
    
    # Extract base image and try to pull it
    local base_image
    base_image=$(yq eval '.base_image.name' "$EXAMPLE_FILE")
    
    if ! podman pull "$base_image"; then
        log ERROR "Failed to pull base image: $base_image"
        return 1
    fi
    
    # TODO: Add actual build test once we have the build infrastructure
    log WARN "Full build test not implemented yet"
}

# Main verification process
main() {
    local failed=false
    
    # Run all checks
    check_yaml_syntax || failed=true
    check_required_fields || failed=true
    check_dependencies || failed=true
    check_verification_header || failed=true
    test_build || failed=true
    
    if [ "$failed" = true ]; then
        log ERROR "Verification failed"
        exit 1
    fi
    
    log INFO "All verification checks passed"
}

main 