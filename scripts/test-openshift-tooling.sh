#!/bin/bash
# Test script to verify OpenShift/Kubernetes tooling installation
# Usage: scripts/test-openshift-tooling.sh <image-name:tag> [container-engine]

set -e

IMAGE="${1:-ansible-ee-minimal:v5}"
CONTAINER_ENGINE="${2:-podman}"

echo "=========================================="
echo "Testing OpenShift/Kubernetes Tooling"
echo "Image: $IMAGE"
echo "Engine: $CONTAINER_ENGINE"
echo "=========================================="

# Test 1: Verify oc binary exists
echo ""
echo "Test 1: Checking for oc binary..."
# Check common locations since 'which' may not be available in minimal images
for OC_PATH in /usr/local/bin/oc /usr/bin/oc; do
    if $CONTAINER_ENGINE run --rm --entrypoint /bin/bash "$IMAGE" -c "test -f $OC_PATH" 2>/dev/null; then
        echo "✓ oc binary found"
        echo "  Location: $OC_PATH"
        break
    fi
done
if [ -z "$OC_PATH" ] || ! $CONTAINER_ENGINE run --rm --entrypoint /bin/bash "$IMAGE" -c "test -f $OC_PATH" 2>/dev/null; then
    echo "✗ oc binary not found"
    exit 1
fi

# Test 2: Verify kubectl binary exists
echo ""
echo "Test 2: Checking for kubectl binary..."
# Check common locations since 'which' may not be available in minimal images
for KUBECTL_PATH in /usr/local/bin/kubectl /usr/bin/kubectl; do
    if $CONTAINER_ENGINE run --rm --entrypoint /bin/bash "$IMAGE" -c "test -f $KUBECTL_PATH" 2>/dev/null; then
        echo "✓ kubectl binary found"
        echo "  Location: $KUBECTL_PATH"
        break
    fi
done
if [ -z "$KUBECTL_PATH" ] || ! $CONTAINER_ENGINE run --rm --entrypoint /bin/bash "$IMAGE" -c "test -f $KUBECTL_PATH" 2>/dev/null; then
    echo "✗ kubectl binary not found"
    exit 1
fi

# Test 3: Verify oc version
echo ""
echo "Test 3: Checking oc version..."
if $CONTAINER_ENGINE run --rm --entrypoint /bin/bash "$IMAGE" -c "oc version --client" >/dev/null 2>&1; then
    echo "✓ oc version command works"
    $CONTAINER_ENGINE run --rm --entrypoint /bin/bash "$IMAGE" -c "oc version --client"
else
    echo "✗ oc version command failed"
    exit 1
fi

# Test 4: Verify kubectl version
echo ""
echo "Test 4: Checking kubectl version..."
if $CONTAINER_ENGINE run --rm --entrypoint /bin/bash "$IMAGE" -c "kubectl version --client" >/dev/null 2>&1; then
    echo "✓ kubectl version command works"
    $CONTAINER_ENGINE run --rm --entrypoint /bin/bash "$IMAGE" -c "kubectl version --client" 2>&1 | head -n 1
else
    echo "✗ kubectl version command failed"
    exit 1
fi

# Test 5: Verify kubernetes.core collection (optional - binaries work without it)
echo ""
echo "Test 5: Checking for kubernetes.core collection (optional)..."
if command -v ansible-navigator >/dev/null 2>&1; then
    if ansible-navigator collections --mode stdout --pull-policy never --eei "$IMAGE" --container-engine "$CONTAINER_ENGINE" 2>&1 | grep -q "kubernetes.core"; then
        echo "✓ kubernetes.core collection found"
        ansible-navigator collections --mode stdout --pull-policy never --eei "$IMAGE" --container-engine "$CONTAINER_ENGINE" 2>&1 | grep "kubernetes.core"
    else
        echo "⚠ kubernetes.core collection not found (binaries work independently - collections are optional)"
        echo "  To enable: uncomment 'kubernetes.core' in files/requirements.yml"
    fi
else
    echo "⚠ ansible-navigator not available, skipping collection check"
fi

# Test 6: Verify oc and kubectl are executable and have correct permissions
echo ""
echo "Test 6: Verifying binary permissions..."
OC_PERMS=$($CONTAINER_ENGINE run --rm --entrypoint /bin/bash "$IMAGE" -c "stat -c '%a' $OC_PATH" 2>/dev/null || echo "unknown")
KUBECTL_PERMS=$($CONTAINER_ENGINE run --rm --entrypoint /bin/bash "$IMAGE" -c "stat -c '%a' $KUBECTL_PATH" 2>/dev/null || echo "unknown")

if [ "$OC_PERMS" != "unknown" ] && { [ "$OC_PERMS" = "755" ] || [ "$OC_PERMS" = "775" ]; }; then
    echo "✓ oc permissions: $OC_PERMS"
else
    echo "⚠ oc permissions: $OC_PERMS (expected 755 or 775)"
fi

if [ "$KUBECTL_PERMS" != "unknown" ] && { [ "$KUBECTL_PERMS" = "755" ] || [ "$KUBECTL_PERMS" = "775" ]; }; then
    echo "✓ kubectl permissions: $KUBECTL_PERMS"
else
    echo "⚠ kubectl permissions: $KUBECTL_PERMS (expected 755 or 775)"
fi

# Test 7: Run functional AAP collection tests
echo ""
echo "Test 7: Running functional AAP collection tests..."
if command -v ansible-navigator >/dev/null 2>&1; then
    echo "Running functional test playbook (files/playbook.yml)..."
    if ansible-navigator run /opt/playbook.yml --mode stdout --pull-policy never --eei "$IMAGE" --container-engine "$CONTAINER_ENGINE" 2>&1; then
        echo "✓ Functional tests passed"
    else
        echo "✗ Functional tests FAILED"
        echo "  Check logs above for details"
        exit 1
    fi
else
    echo "⚠ ansible-navigator not available, skipping functional tests"
    echo "  Install with: pip install ansible-navigator"
    echo "  Or run playbook manually: ansible-playbook /opt/playbook.yml"
fi

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="

