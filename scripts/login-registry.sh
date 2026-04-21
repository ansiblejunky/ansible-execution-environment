#!/bin/bash
# Script to securely log in to registry.redhat.io
# Usage: ./scripts/login-registry.sh [container-engine]
# Environment variables expected:
#   REDHAT_REGISTRY_USERNAME - Red Hat registry username
#   REDHAT_REGISTRY_PASSWORD - Red Hat registry password
#   CONTAINER_ENGINE - Container engine (podman/docker), defaults to podman

set -e

CONTAINER_ENGINE="${1:-podman}"
REGISTRY="registry.redhat.io"

# Check if container engine is available
if ! command -v "$CONTAINER_ENGINE" &> /dev/null; then
    echo "❌ Error: $CONTAINER_ENGINE not found"
    exit 1
fi

# Check if credentials are provided
if [ -z "$REDHAT_REGISTRY_USERNAME" ] || [ -z "$REDHAT_REGISTRY_PASSWORD" ]; then
    echo "⚠ Warning: Registry credentials not provided, skipping login"
    exit 0
fi

echo "🔐 Logging in to $REGISTRY..."

# Login with credentials
if echo "$REDHAT_REGISTRY_PASSWORD" | "$CONTAINER_ENGINE" login "$REGISTRY" \
    --username "$REDHAT_REGISTRY_USERNAME" \
    --password-stdin > /dev/null 2>&1; then
    echo "✓ Successfully logged in to $REGISTRY"
    exit 0
else
    echo "❌ Error: Failed to log in to $REGISTRY"
    exit 1
fi
