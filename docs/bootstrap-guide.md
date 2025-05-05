# Bootstrap Environment Guide

This guide explains how to configure and use the bootstrap environment for the Ansible Execution Environment.

## Prerequisites

Before starting, ensure you have:

1. Red Hat Account credentials with access to:
   - registry.redhat.io
   - registry.connect.redhat.com
   - Red Hat Automation Hub

2. Required tools:
   - podman
   - ansible-builder
   - ansible-navigator
   - python3/pip3
   - dig (for DNS checks)

## Configuration

### 1. Environment Setup

1. Copy the example environment file:
   ```bash
   cp .env-example .env
   ```

2. Configure container engine settings in `.env`:
   ```bash
   CONTAINER_ENGINE=podman     # Options: podman, docker
   TARGET_TAG=latest
   TARGET_NAME=ansible-ee-minimal
   TARGET_HUB=quay.io/your-org
   ```

3. Set up authentication:
   
   a. Registry Authentication:
   - Get credentials from [Red Hat Registry Service Account](https://access.redhat.com/terms-based-registry/)
   - Configure in `.env`:
     ```bash
     REGISTRY_USERNAME=your-username  # Can be email or service account name
     REGISTRY_PASSWORD=your-token
     ```

   b. Automation Hub Authentication:
   - Get offline token from [Red Hat Hybrid Cloud Console](https://console.redhat.com/ansible/automation-hub)
   - Save to `offline-token.txt`
   - Configure in `.env`:
     ```bash
     ANSIBLE_HUB_TOKEN=your-hub-token-here
     ```

### 2. Collection Management

The bootstrap process automatically downloads the three most recent versions of required collections. Configure custom Python package repository if needed:

```bash
PIP_INDEX_URL=https://pypi.org/simple
```

## Usage

### 1. Basic Bootstrap

Run the bootstrap script:
```bash
source .env && ./files/bootstrap/bootstrap_env.sh
```

This will:
- Validate environment variables
- Check DNS resolution
- Authenticate with registries
- Download required collections
- Set up Python virtual environment

### 2. Advanced Options

The bootstrap script supports several options:

```bash
./files/bootstrap/bootstrap_env.sh [options]

Options:
    -h, --help          Show help message
    -v, --verbose       Enable verbose output
    -f, --force         Force setup even if already initialized
    --skip-deps         Skip dependency installation
```

### 3. Token Refresh

To refresh the Automation Hub token:
```bash
export ANSIBLE_HUB_TOKEN=$(cat offline-token.txt) && ./files/maintenance/token_refresh.sh
```

## Integration with EE Build

The bootstrap environment integrates with the Execution Environment build process:

1. Environment validation ensures all prerequisites are met
2. Authentication is set up for all required registries
3. Collections are downloaded locally for faster builds
4. Python dependencies are managed in a virtual environment

## Troubleshooting

Common issues and solutions:

1. Registry Authentication Failures:
   - Verify credentials in `.env`
   - Check token expiration
   - Ensure network connectivity

2. Collection Download Issues:
   - Check Automation Hub token
   - Verify API access
   - Check disk space for downloads

3. DNS Resolution Problems:
   - Verify network connectivity
   - Check DNS server accessibility
   - Review firewall rules

## Related Documentation

- [ADR-0006: Authentication Flow and Token Handling](docs/adrs/0006-authentication-flow-and-token-handling.md)
- [Execution Environment Configuration](execution-environment.yml)
- [Bootstrap Environment Script](files/bootstrap/bootstrap_env.sh)

## Security Notes

1. Token Storage:
   - Keep `.env` file secure (600 permissions)
   - Never commit tokens to version control
   - Regularly rotate tokens

2. Access Control:
   - Use service accounts where possible
   - Follow principle of least privilege
   - Monitor access patterns

## Maintenance

Regular maintenance tasks:

1. Token Management:
   - Monitor token expiration
   - Rotate tokens periodically
   - Update credentials as needed

2. Collection Updates:
   - Review downloaded versions
   - Clean up old collections
   - Update version requirements 