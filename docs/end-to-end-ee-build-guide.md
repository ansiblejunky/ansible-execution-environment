# End-to-End Guide: Building Ansible Execution Environments

This guide provides comprehensive instructions for building, testing, and deploying Ansible Execution Environments using a container-based approach. Following this methodology ensures consistent results regardless of your local environment setup.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Setup Container Environment](#setup-container-environment)
3. [Configure Environment Variables](#configure-environment-variables)
4. [Build Execution Environment](#build-execution-environment)
5. [Using Custom Python Package Repositories](#using-custom-python-package-repositories)
6. [Test Execution Environment](#test-execution-environment)
7. [Security Scanning](#security-scanning)
8. [AAP 2.5 Integration Testing](#aap-25-integration-testing)
9. [Public Galaxy Hub Integration](#public-galaxy-hub-integration)
10. [Private Automation Hub Integration](#private-automation-hub-integration)
11. [AAP 2.5 Integration](#aap-25-integration)
12. [Deployment and Distribution](#deployment-and-distribution)
13. [Troubleshooting](#troubleshooting)

## Prerequisites

Minimal requirements to use this project:

- A container engine (podman or docker)
- Git (to clone this repository)
- Basic familiarity with Ansible and containers

You do NOT need:
- ansible-builder
- ansible-navigator
- ansible-core

These tools will be used within the container environment.

## Setup Container Environment

1. Clone this repository:
   ```bash
   git clone https://github.com/your-organization/ansible-execution-environment.git
   cd ansible-execution-environment
   ```

2. Verify your container engine is working:
   ```bash
   # For podman
   podman info
   
   # For docker
   docker info
   ```

3. Authenticate with required registries:
   ```bash
   # Red Hat registry (required for AAP base images)
   podman login registry.redhat.io
   
   # Your container registry for publishing
   podman login quay.io
   ```

## Configure Environment Variables

Set the following environment variables:

```bash
# Required for private Automation Hub access
export ANSIBLE_HUB_TOKEN=your_token_here

# Optional: specify container engine (default: podman)
export CONTAINER_ENGINE=podman

# Optional: specify the target tag for your image
export TARGET_TAG=1.0.0

# Optional: specify the target registry
export TARGET_HUB=quay.io/your-org

# Optional: specify custom Python package repository
export PIP_INDEX_URL=https://your-custom-pypi.example.com/simple

# Optional: for AAP 2.5 integration testing
export AAP_URL=https://your-aap-controller.example.com
export AAP_USERNAME=your-username
export AAP_PASSWORD=your-password
export AAP_VERIFY_SSL=false
```

## Build Execution Environment

We offer two approaches for building execution environments:

### Option 1: Using container-test.sh (Recommended)

This script handles the entire build process within a container:

```bash
./files/container-test.sh
```

### Option 2: Using the Makefile with container-based workflow

```bash
# Run the container with the project mounted
podman run -it --rm \
  -v $PWD:/home/runner/project:Z \
  -w /home/runner/project \
  -e ANSIBLE_HUB_TOKEN=$ANSIBLE_HUB_TOKEN \
  registry.redhat.io/ansible-automation-platform-25/ansible-builder-rhel9:latest \
  make build
```

## Using Custom Python Package Repositories

For organizations with private Python package repositories or those who need to use alternate PyPI mirrors, we've added support for the `PIP_INDEX_URL` environment variable.

### Building with PIP_INDEX_URL Support

Use our enhanced build script which automatically handles custom Python package repositories:

```bash
# Set your custom Python package repository URL
export PIP_INDEX_URL=https://your-custom-pypi.example.com/simple

# Run the build script
./files/build-with-pip-index.sh
```

This script will:

1. Create a temporary build configuration with your custom PIP_INDEX_URL
2. Run ansible-builder within a container with the proper settings
3. Pass the PIP_INDEX_URL to both the ansible-builder process and the final container

### Common PIP_INDEX_URL Examples

#### Using a corporate PyPI mirror:
```bash
export PIP_INDEX_URL=https://pypi.corp-example.com/simple
```

#### Using a self-hosted DevPI server:
```bash
export PIP_INDEX_URL=https://devpi.example.com/root/pypi/+simple/
```

#### Using an Artifactory repository:
```bash
export PIP_INDEX_URL=https://artifactory.example.com/artifactory/api/pypi/pypi-virtual/simple
```

### Verifying PIP_INDEX_URL Configuration

To verify that your execution environment is using the correct Python package repository:

```bash
# Run a container with your execution environment
podman run --rm -it your-ee:latest bash

# Inside the container, check the pip.conf file
cat /etc/pip.conf

# Or check by running pip directly
pip config list
```

## Test Execution Environment

Validate your execution environment using our test playbooks:

```bash
# Run tests within the container
podman run -it --rm \
  -v $PWD:/home/runner/project:Z \
  -w /home/runner/project \
  -e ANSIBLE_HUB_TOKEN=$ANSIBLE_HUB_TOKEN \
  registry.redhat.io/ansible-automation-platform-25/ansible-builder-rhel9:latest \
  make test
```

## Security Scanning

We provide a comprehensive security scanning capability for execution environments, utilizing multiple industry-standard tools.

### Running Security Scans

To scan your execution environment for security vulnerabilities:

```bash
# Set optional scan configuration
export TARGET_NAME=your-execution-environment
export TARGET_TAG=latest
export SCAN_TYPE=all  # Options: all, trivy, openscap, grype
export REPORT_DIR=./security-reports

# Run the security scanner
./files/security-scan.sh
```

### Scan Types

The security scanner supports multiple scanning tools:

1. **Trivy**: A comprehensive vulnerability scanner that detects vulnerabilities in container images
2. **Grype**: A vulnerability scanner that provides fast and accurate results
3. **OpenSCAP**: A compliance scanner that checks against security standards like CIS

You can run all scanners or select specific ones using the `SCAN_TYPE` environment variable.

### Scan Reports

The security scanner generates detailed reports in multiple formats:

- JSON reports for programmatic analysis
- HTML reports for human review
- A combined HTML report that aggregates results from all scanners

Reports are organized in the `REPORT_DIR` directory:

```
security-reports/
├── combined/
│   └── your-ee-latest-20230515-120000.html
├── trivy/
│   ├── your-ee-latest-20230515-120000.json
│   └── your-ee-latest-20230515-120000.html
├── grype/
│   ├── your-ee-latest-20230515-120000.json
│   └── your-ee-latest-20230515-120000.txt
└── openscap/
    └── your-ee-latest-20230515-120000.html
```

### Integrating Security Scanning in CI/CD

For continuous security validation, add the scanning step to your CI/CD pipeline:

```yaml
# Example GitHub Actions step
- name: Security Scan Execution Environment
  run: |
    export TARGET_NAME=your-execution-environment
    export TARGET_TAG=${{ github.sha }}
    export REPORT_DIR=./security-reports
    ./files/security-scan.sh
```

## AAP 2.5 Integration Testing

We provide automated testing for validating execution environments with AAP 2.5.

### Running AAP 2.5 Integration Tests

To test your execution environment with AAP 2.5:

```bash
# Set required AAP 2.5 connection details
export AAP_URL=https://your-aap-controller.example.com
export AAP_USERNAME=your-username
export AAP_PASSWORD=your-password
export AAP_VERIFY_SSL=false  # Set to true for production environments

# Set execution environment details
export TARGET_NAME=your-execution-environment
export TARGET_TAG=latest
export TARGET_HUB=quay.io/your-org

# Run the integration test
./files/test-aap-integration.sh
```

### What the Integration Test Validates

The AAP 2.5 integration test performs the following validations:

1. Tests the execution environment locally to verify basic functionality
2. Pushes the execution environment to a registry accessible by AAP
3. Registers the execution environment with AAP using the Controller API
4. Creates a test job template that uses the execution environment
5. Runs the test job and verifies successful execution

### Test Requirements

To successfully run the AAP 2.5 integration test, you need:

1. A running AAP 2.5 instance with API access
2. Admin credentials for the AAP instance
3. A container registry that your AAP instance can access
4. Network connectivity between your testing environment and AAP

### Interpreting Test Results

The test provides detailed output about each validation step:

- Local functionality testing
- Registry push operations
- AAP execution environment registration
- Job template creation and execution
- Test job results

Any failures will be clearly indicated with error messages that can help you identify and resolve issues.

## Public Galaxy Hub Integration

To build an execution environment using public Galaxy collections:

1. Create or modify your requirements.yml file:
   ```yaml
   ---
   collections:
     - name: ansible.posix
     - name: community.general
   ```

2. Build the execution environment:
   ```bash
   podman run -it --rm \
     -v $PWD:/home/runner/project:Z \
     -w /home/runner/project \
     registry.redhat.io/ansible-automation-platform-25/ansible-builder-rhel9:latest \
     ansible-builder build --file execution-environment.yml -t galaxy-ee:latest --container-runtime podman
   ```

3. Test the execution environment:
   ```bash
   podman run --rm galaxy-ee:latest ansible --version
   ```

## Private Automation Hub Integration

To build an execution environment using private Automation Hub collections:

1. Create or modify your requirements.yml file:
   ```yaml
   ---
   collections:
     - name: redhat.satellite
     - name: redhat.rhv
   ```

2. Ensure your ANSIBLE_HUB_TOKEN is set:
   ```bash
   export ANSIBLE_HUB_TOKEN=your_token_here
   ```

3. Build the execution environment:
   ```bash
   podman run -it --rm \
     -v $PWD:/home/runner/project:Z \
     -w /home/runner/project \
     -e ANSIBLE_HUB_TOKEN=$ANSIBLE_HUB_TOKEN \
     registry.redhat.io/ansible-automation-platform-25/ansible-builder-rhel9:latest \
     ansible-builder build --file execution-environment.yml -t private-ee:latest --container-runtime podman
   ```

4. Test the execution environment:
   ```bash
   podman run --rm private-ee:latest ansible --version
   ```

## AAP 2.5 Integration

To integrate your execution environment with AAP 2.5:

1. Push your execution environment to a registry accessible by AAP:
   ```bash
   podman tag private-ee:latest quay.io/your-org/private-ee:latest
   podman push quay.io/your-org/private-ee:latest
   ```

2. In the AAP 2.5 UI:
   - Navigate to Admin > Execution Environments
   - Click "Add"
   - Enter the image URL (e.g., quay.io/your-org/private-ee:latest)
   - Add any necessary credentials
   - Click "Save"

3. Verify the execution environment is available for use in Job Templates

## Deployment and Distribution

To distribute your execution environment:

1. Add appropriate tags:
   ```bash
   podman tag private-ee:latest quay.io/your-org/private-ee:1.0.0
   podman tag private-ee:latest quay.io/your-org/private-ee:latest
   ```

2. Push to your registry:
   ```bash
   podman push quay.io/your-org/private-ee:1.0.0
   podman push quay.io/your-org/private-ee:latest
   ```

3. Document the image URL for users:
   ```
   Image: quay.io/your-org/private-ee:1.0.0
   ```

## Troubleshooting

### Authentication Issues

If you encounter authentication problems:

```bash
# Verify your registry authentication
podman login registry.redhat.io
podman login quay.io

# Ensure your ANSIBLE_HUB_TOKEN is correctly set
echo $ANSIBLE_HUB_TOKEN
```

### Build Failures

If the build fails:

1. Check for errors in the build output
2. Verify your requirements.yml file is valid
3. Ensure all required collections are accessible
4. Check connectivity to the Ansible Galaxy/Hub

### Container Issues

If you experience container-related issues:

```bash
# Check container engine status
podman info

# Remove any dangling images
podman system prune -a

# Verify storage space
df -h
```

### PIP_INDEX_URL Issues

If you encounter issues with custom Python package repositories:

1. Verify the URL is correctly formatted (should end with /simple)
2. Check connectivity to the repository from within the container
3. Ensure the repository contains all required packages
4. Try using the `--trusted-host` flag if dealing with internal certificates:
   ```bash
   export PIP_INDEX_URL=https://your-repo.example.com/simple
   export PIP_TRUSTED_HOST=your-repo.example.com
   ```

### AAP 2.5 Integration Issues

If you encounter problems with AAP 2.5 integration:

1. Verify network connectivity between your environment and AAP
2. Check that your AAP credentials are correct
3. Ensure the registry containing your execution environment is accessible to AAP
4. Verify that you have admin permissions in AAP to add execution environments
5. Check the AAP logs for detailed error messages

### Security Scanning Issues

If you encounter problems with security scanning:

1. Verify that your container engine has access to the internet to download scanning tools
2. Ensure you have enough disk space for reports (scans can generate large reports)
3. Check if your execution environment exists before scanning
4. Try scanning with a specific tool (e.g., `SCAN_TYPE=trivy`) to isolate issues

---

For additional help or to report issues, please open a GitHub issue or contact the maintainers. 