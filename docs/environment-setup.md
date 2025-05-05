# Environment Setup Guide

This document provides detailed information about the environment variables required for the Ansible Execution Environment project.

## Prerequisites

### Registry Authentication

Before starting, ensure you have access to the required registries:

1. Red Hat Container Registry (registry.redhat.io)
   - Purpose: Access to base container images
   - Required credentials: Red Hat account username and password
   - Login command:
     ```bash
     podman login registry.redhat.io
     # Username: your-redhat-username
     # Password: your-redhat-password
     ```

2. Red Hat Connect Registry (registry.connect.redhat.com)
   - Purpose: Access to certified Ansible content and automation hub
   - Required credentials: API token
   - How to get token:
     1. Login to [Red Hat Customer Portal](https://access.redhat.com)
     2. Go to [Red Hat Ansible Automation Platform](https://console.redhat.com/ansible/automation-hub)
     3. Navigate to "API Token" section
     4. Generate a new token
   - Login command:
     ```bash
     podman login registry.connect.redhat.com --username ansible-automation-platform
     # Password: your-ansible-hub-token
     ```

3. Quay.io (Optional)
   - Purpose: Additional container registry for custom images
   - Required credentials: Quay.io username and password (if using)
   - Login command:
     ```bash
     podman login quay.io
     # Username: your-quay-username
     # Password: your-quay-password
     ```

## Required Environment Variables

### Container Engine Configuration

1. `CONTAINER_ENGINE`
   - Purpose: Specifies which container engine to use
   - Required: Yes
   - Options: `podman` or `docker`
   - Example: `CONTAINER_ENGINE=podman`

2. `TARGET_TAG`
   - Purpose: Specifies the tag for the built container image
   - Required: Yes
   - Format: Standard container tag format
   - Example: `TARGET_TAG=latest`

3. `TARGET_NAME`
   - Purpose: Name of the execution environment image
   - Required: Yes
   - Format: Valid container image name
   - Example: `TARGET_NAME=ansible-ee-minimal`

4. `TARGET_HUB`
   - Purpose: Container registry where the image will be pushed
   - Required: Yes
   - Format: Valid container registry URL
   - Example: `TARGET_HUB=quay.io/your-org`

### Container Registry Authentication

5. `REGISTRY_USERNAME`
   - Purpose: Username for registry.redhat.io authentication
   - Required: Yes
   - Format: Your Red Hat account username
   - Example: `REGISTRY_USERNAME=your-redhat-username`

6. `REGISTRY_PASSWORD`
   - Purpose: Password for registry.redhat.io authentication
   - Required: Yes
   - Format: Your Red Hat account password
   - Example: `REGISTRY_PASSWORD=your-secure-password`

7. `ANSIBLE_HUB_TOKEN`
   - Purpose: Authentication token for hub.redhat.io (Ansible Automation Hub)
   - Required: Yes
   - How to obtain: Via Ansible Automation Hub web interface
   - Example: `ANSIBLE_HUB_TOKEN=eyJhbGciOiJIUzI1NiIsIn...`

8. `QUAY_USERNAME` (Optional)
   - Purpose: Username for Quay.io authentication
   - Required: No
   - Example: `QUAY_USERNAME=your-quay-username`

9. `QUAY_PASSWORD` (Optional)
   - Purpose: Password for Quay.io authentication
   - Required: No
   - Example: `QUAY_PASSWORD=your-quay-password`

### Python Package Configuration

10. `PIP_INDEX_URL`
    - Purpose: Custom Python package repository URL (if needed)
    - Required: No
    - Default: `https://pypi.org/simple`
    - Example: `PIP_INDEX_URL=https://pypi.org/simple`

### AAP 2.5 Integration Testing

11. `AAP_URL`
    - Purpose: URL of your Ansible Automation Platform instance
    - Required: For integration testing only
    - Format: Valid HTTPS URL
    - Example: `AAP_URL=https://your-aap-controller.example.com`

12. `AAP_USERNAME`
    - Purpose: Username for AAP authentication
    - Required: For integration testing only
    - Example: `AAP_USERNAME=admin`

13. `AAP_PASSWORD`
    - Purpose: Password for AAP authentication
    - Required: For integration testing only
    - Example: `AAP_PASSWORD=your-secure-password`

14. `AAP_VERIFY_SSL`
    - Purpose: Whether to verify SSL certificates for AAP connections
    - Required: For integration testing only
    - Options: `true` or `false`
    - Example: `AAP_VERIFY_SSL=false`

## Setting Up Your Environment

1. Copy the `.env-example` file to `.env`:
   ```bash
   cp .env-example .env
   ```

2. Edit the `.env` file with your specific values:
   ```bash
   vim .env  # or use your preferred editor
   ```

3. Validate your environment setup:
   ```bash
   ./files/bootstrap/bootstrap_validate.sh --env-only
   ```

## Security Notes

1. Never commit the `.env` file to version control
2. Keep your `ANSIBLE_HUB_TOKEN` secure and rotate it regularly
3. Use strong passwords for AAP credentials
4. Consider using a secrets management solution for production environments
5. Store registry credentials securely and never commit them to version control
6. Consider using credential helpers for container registry authentication
7. Rotate registry access tokens periodically

## Troubleshooting

If you encounter environment-related issues:

1. Run the validation script with verbose output:
   ```bash
   ./files/bootstrap/bootstrap_validate.sh -v
   ```

2. Check the logs for specific error messages
3. Verify all required variables are set correctly
4. Ensure you have the necessary permissions for the container registry

### Registry Authentication Issues

Common issues and solutions:

1. DNS Resolution Issues
   - Check your DNS configuration:
     ```bash
     cat /etc/resolv.conf
     dig registry.connect.redhat.com
     host registry.connect.redhat.com
     ```
   - Verify connectivity:
     ```bash
     ping registry.connect.redhat.com
     ```

2. Network Access Issues
   - Check if you're behind a proxy
   - Verify firewall rules allow access to Red Hat domains
   - Test basic connectivity to Red Hat services

3. Authentication Failures
   - Verify your Red Hat subscription is active
   - Ensure your token hasn't expired
   - Check if you need to accept any agreements in the Red Hat portal

4. Registry Connection Problems
   - Try manual login to isolate authentication vs. connection issues
   - Check Red Hat's system status page
   - Verify you're using the correct registry endpoints

5. "Invalid username/password" for registry.redhat.io
   - Verify your Red Hat account credentials
   - Ensure your Red Hat subscription is active
   - Try logging in to [access.redhat.com](https://access.redhat.com)

6. "Invalid username/password" for hub.redhat.io
   - Verify your Ansible Hub token is current
   - Ensure you're using 'ansible-automation-platform' as the username
   - Generate a new token if needed

7. Registry Connection Issues
   - Check your network connectivity
   - Verify any proxy settings
   - Review podman configuration:
     ```bash
     podman info
     ```
   - Check registry status:
     - [Red Hat Registry Status](https://status.redhat.com)
     - [Quay.io Status](https://status.quay.io)

8. Token Expiration
   - Ansible Hub tokens expire after 30 days by default
   - Set a reminder to rotate tokens before expiration
   - Consider automating token rotation for production environments

9. "No such host" error for Automation Hub
   - Try using the alternative endpoint:
     ```bash
     podman login console.redhat.com/api/automation-hub
     ```
   - Check your DNS resolution
   - Verify network connectivity to Red Hat services
   - Ensure you're not behind a restrictive proxy 