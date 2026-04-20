#!/bin/bash
# Validate collection dependencies for ansible-execution-environment
# ADR-0008: Collection Dependency Validation
#
# This script checks if collections that require OpenShift CLI tools
# are enabled in requirements.yml, and ensures oc-install.env is configured.
#
# Usage:
#   ./scripts/validate-collection-deps.sh
#
# Environment Variables:
#   STRICT_VALIDATION=true   - Fail build on validation errors (default: false, warnings only)
#   SKIP_VALIDATION=true     - Skip validation entirely (default: false)
#   VALIDATION_VERBOSE=true  - Show detailed validation checks (default: false)
#
# Exit Codes:
#   0 - Validation passed or warnings only (STRICT_VALIDATION=false)
#   1 - Validation failed (STRICT_VALIDATION=true)

set -e

# Configuration
REQUIREMENTS_FILE="files/requirements.yml"
OC_CONFIG_FILE="files/optional-configs/oc-install.env"
STRICT_VALIDATION="${STRICT_VALIDATION:-false}"
SKIP_VALIDATION="${SKIP_VALIDATION:-false}"
VALIDATION_VERBOSE="${VALIDATION_VERBOSE:-false}"

# Collections that require OpenShift CLI tools (oc/kubectl)
OPENSHIFT_REQUIRED_COLLECTIONS=(
    "kubernetes.core"
    "redhat.openshift"
    "ansible.platform"
    "ansible.eda"
)

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [ "$VALIDATION_VERBOSE" = "true" ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Skip validation if requested
if [ "$SKIP_VALIDATION" = "true" ]; then
    log_info "Validation skipped (SKIP_VALIDATION=true)"
    exit 0
fi

# Check if requirements.yml exists
if [ ! -f "$REQUIREMENTS_FILE" ]; then
    log_error "Requirements file not found: $REQUIREMENTS_FILE"
    exit 1
fi

log_info "Validating collection dependencies..."
log_verbose "Requirements file: $REQUIREMENTS_FILE"
log_verbose "OpenShift config file: $OC_CONFIG_FILE"
log_verbose "Strict validation: $STRICT_VALIDATION"

# Find enabled collections that require OpenShift tooling
ENABLED_COLLECTIONS=()
VALIDATION_FAILED=false

for collection in "${OPENSHIFT_REQUIRED_COLLECTIONS[@]}"; do
    # Check if collection is uncommented in requirements.yml
    # Look for lines like:
    #   - name: kubernetes.core
    # But NOT:
    #   # - name: kubernetes.core
    #   #- name: kubernetes.core

    if grep -E "^[[:space:]]*-[[:space:]]*name:[[:space:]]*${collection}[[:space:]]*(#.*)?$" "$REQUIREMENTS_FILE" > /dev/null 2>&1; then
        ENABLED_COLLECTIONS+=("$collection")
        log_verbose "Found enabled collection: $collection"
    else
        log_verbose "Collection not enabled or commented: $collection"
    fi
done

# If no OpenShift-required collections are enabled, validation passes
if [ ${#ENABLED_COLLECTIONS[@]} -eq 0 ]; then
    log_success "No OpenShift-dependent collections enabled - validation passed"
    exit 0
fi

# Collections are enabled - check if OpenShift tooling is configured
log_info "Found ${#ENABLED_COLLECTIONS[@]} collection(s) requiring OpenShift CLI tools:"
for collection in "${ENABLED_COLLECTIONS[@]}"; do
    echo "  - $collection"
done

if [ -f "$OC_CONFIG_FILE" ]; then
    log_success "OpenShift tooling configured: $OC_CONFIG_FILE"

    # Verify the config file has OC_VERSION set
    if grep -E "^OC_VERSION=" "$OC_CONFIG_FILE" > /dev/null 2>&1; then
        OC_VERSION=$(grep -E "^OC_VERSION=" "$OC_CONFIG_FILE" | cut -d'=' -f2)
        log_success "OpenShift version configured: $OC_VERSION"
    else
        log_warning "OC_VERSION not set in $OC_CONFIG_FILE"
        if [ "$STRICT_VALIDATION" = "true" ]; then
            VALIDATION_FAILED=true
        fi
    fi

    if [ "$VALIDATION_FAILED" = "false" ]; then
        log_success "Collection dependency validation PASSED"
        exit 0
    fi
else
    log_error "OpenShift tooling NOT configured!"
    VALIDATION_FAILED=true
fi

# Validation failed - provide guidance
if [ "$VALIDATION_FAILED" = "true" ]; then
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ Collection Dependency Validation FAILED                          ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "The following collections require OpenShift CLI tools (oc/kubectl):"
    for collection in "${ENABLED_COLLECTIONS[@]}"; do
        echo "  • $collection"
    done
    echo ""
    echo "But OpenShift tooling is not configured."
    echo ""
    echo -e "${BLUE}To fix this:${NC}"
    echo ""
    echo "  1. Create the OpenShift configuration file:"
    echo -e "     ${GREEN}echo 'OC_VERSION=stable-4.21' > $OC_CONFIG_FILE${NC}"
    echo ""
    echo "  2. Rebuild with OpenShift support:"
    echo -e "     ${GREEN}make build-openshift-tarball${NC}"
    echo ""
    echo -e "${BLUE}Alternative:${NC}"
    echo ""
    echo "  If you don't need these collections, comment them out in:"
    echo "     $REQUIREMENTS_FILE"
    echo ""
    echo "  Example:"
    echo "     # - name: kubernetes.core"
    echo "     # - name: ansible.platform"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  • ADR-0007: docs/adrs/0007-aap-collection-dependencies.md"
    echo "  • ADR-0008: docs/adrs/0008-collection-dependency-validation.md"
    echo "  • How-to: docs/how-to/enable-kubernetes-openshift.md"
    echo ""

    if [ "$STRICT_VALIDATION" = "true" ]; then
        echo -e "${RED}Build FAILED due to validation errors (STRICT_VALIDATION=true)${NC}"
        echo ""
        exit 1
    else
        echo -e "${YELLOW}⚠ WARNING: Continuing with build (STRICT_VALIDATION=false)${NC}"
        echo -e "${YELLOW}⚠ Your build may succeed but playbooks will FAIL at runtime${NC}"
        echo ""
        echo "To make this validation strict (fail builds), set:"
        echo "  export STRICT_VALIDATION=true"
        echo ""
        exit 0
    fi
fi
