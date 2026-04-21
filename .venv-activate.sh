#!/bin/bash
# Virtual environment activation helper for ansible-execution-environment
# Usage: source .venv-activate.sh
# ADR-0006: Development Environment Setup

set -e

# Check if script is being sourced (not executed)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script must be sourced, not executed."
    echo "Usage: source .venv-activate.sh"
    exit 1
fi

# Check if .venv exists
if [ ! -d .venv ]; then
    echo "❌ ERROR: Virtual environment not found at .venv/"
    echo ""
    echo "Create it by running:"
    echo "  make setup"
    echo ""
    echo "Or manually:"
    echo "  python3.11 -m venv .venv"
    echo "  source .venv/bin/activate"
    echo "  pip install -r requirements-dev.txt"
    return 1
fi

# Activate virtual environment
source .venv/bin/activate

# Display environment info
echo "✓ Development environment activated"
echo ""
echo "Environment Details:"
echo "  Python:            $(python --version 2>&1)"
echo "  Python Path:       $(which python)"
echo "  pip:               $(pip --version 2>&1 | cut -d' ' -f1-2)"
echo ""

# Check for ansible tools
if command -v ansible-builder &> /dev/null; then
    echo "  ansible-builder:   $(ansible-builder --version 2>&1 | head -1)"
else
    echo "  ansible-builder:   ❌ not found (run: pip install -r requirements-dev.txt)"
fi

if command -v ansible-navigator &> /dev/null; then
    echo "  ansible-navigator: $(ansible-navigator --version 2>&1 | head -1)"
else
    echo "  ansible-navigator: ❌ not found (run: pip install -r requirements-dev.txt)"
fi

if command -v ansible &> /dev/null; then
    echo "  ansible-core:      $(ansible --version 2>&1 | head -1)"
else
    echo "  ansible-core:      ❌ not found (run: pip install -r requirements-dev.txt)"
fi

echo ""

# Check for ANSIBLE_HUB_TOKEN
if [ -z "$ANSIBLE_HUB_TOKEN" ]; then
    echo "⚠  WARNING: ANSIBLE_HUB_TOKEN not set"
    echo "  Set it with: export ANSIBLE_HUB_TOKEN=\$(cat token)"
    echo ""
fi

echo "Ready to build! Try: make build"
