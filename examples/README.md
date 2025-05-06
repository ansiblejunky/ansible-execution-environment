# Execution Environment Examples

This directory contains example configurations for different use cases. Each example demonstrates how to customize the execution environment for specific needs.

## Available Examples

### 1. Minimal Environment (`minimal-ee.yml`)
- Basic environment with minimal tools
- Uses free UBI base image
- No optional tools installed
- Perfect for:
  - CI/CD pipelines where minimal size is important
  - Basic Ansible automation tasks
  - Learning and development environments

### 2. Cloud Provider Environments

#### AWS Cloud Environment (`cloud-aws-ee.yml`)
- AWS-focused cloud automation tools
- Includes:
  - AWS CLI v2
  - AWS Session Manager plugin
  - Terraform
  - Packer
- Perfect for:
  - AWS infrastructure management
  - EC2 automation
  - AWS service configuration
  - CloudFormation alternatives

#### Google Cloud Environment (`cloud-gcp-ee.yml`)
- GCP-focused cloud automation tools
- Includes:
  - Google Cloud SDK
  - GKE authentication plugin
  - Cloud SQL Proxy
  - Terraform
  - Packer
- Perfect for:
  - GCP infrastructure management
  - GKE cluster management
  - Cloud SQL administration
  - GCP service automation

#### OpenShift Environment (`cloud-openshift-ee.yml`)
- OpenShift/Kubernetes focused tools
- Includes:
  - OpenShift CLI (oc)
  - Helm
  - Container tools (podman, skopeo, buildah)
  - OpenSCAP for container scanning
- Perfect for:
  - OpenShift cluster management
  - Container deployment automation
  - Kubernetes resource management
  - Container security scanning

### 3. Security-Focused Environment (`security-focused-ee.yml`)
- Includes security scanning and compliance tools
- OpenSCAP scanner enabled
- Kerberos authentication support
- Perfect for:
  - Security compliance automation
  - System hardening tasks
  - Security auditing and reporting

## Using These Examples

1. Choose the example closest to your needs:
   ```bash
   # For AWS automation
   cp examples/cloud-aws-ee.yml my-ee-variables.yml
   
   # For GCP automation
   cp examples/cloud-gcp-ee.yml my-ee-variables.yml
   
   # For OpenShift automation
   cp examples/cloud-openshift-ee.yml my-ee-variables.yml
   ```

2. Configure Authentication:
   - AWS: Set up AWS credentials or use IAM roles
   - GCP: Provide service account credentials
   - OpenShift: Configure kubeconfig and registry authentication
   - Azure: Set up service principal credentials

3. Customize the Configuration:
   - Enable/disable specific tools
   - Update dependency files
   - Adjust build steps
   - Add custom tools or steps

4. Build Your Environment:
   ```bash
   ansible-builder build -v3 -t my-ee:latest
   ```

## Customization Tips

1. **Base Image Selection**
   - Use UBI minimal for smaller images
   - Use AAP images for Red Hat support
   - Consider authentication requirements

2. **Tool Selection**
   - Only enable tools you need
   - Consider image size impact
   - Version pin for stability
   - Mix and match tools from different examples

3. **Dependencies**
   - Keep requirements files minimal
   - Use version pinning
   - Separate optional dependencies
   - Include cloud provider SDKs

4. **Build Steps**
   - Remove unnecessary validation steps
   - Keep cleanup steps for production
   - Add custom steps as needed
   - Consider build time vs functionality

## Cloud Provider Authentication

### AWS
- Use AWS credentials file
- Support for AWS SSO
- IAM role configuration
- AWS STS support

### Google Cloud
- Service account key management
- GKE authentication
- Workload identity support
- Application default credentials

### OpenShift
- Kubeconfig management
- Service account tokens
- OAuth authentication
- Registry authentication

## Need More Examples?

If you need help creating a custom configuration for your use case:
1. Check the documentation in `docs/`
2. Review ADR-0007 for design decisions
3. Open an issue for feature requests 