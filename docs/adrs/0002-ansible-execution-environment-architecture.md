# [ADR-0002] Ansible Execution Environment Architecture

## Status

Accepted

## Context

Ansible Execution Environments (EE) are container images that provide a consistent and isolated environment for running Ansible automation. We need to define our approach to:
- Building and maintaining execution environments
- Managing dependencies
- Ensuring reproducibility
- Supporting development and testing workflows
- Handling security requirements

## Decision

We will implement an Ansible Execution Environment with the following architecture:

1. Base Image Selection:
   - Use Red Hat's official EE base images (`registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9`)
   - Leverage RHEL 9 for enhanced security and performance

2. Build Process:
   - Use Makefile-driven build process for consistency and ease of use
   - Implement multi-stage builds to minimize final image size
   - Use ansible-builder for EE construction

3. Dependency Management:
   - Centralize dependencies in requirements files:
     - `requirements.yml` for Ansible collections
     - `requirements.txt` for Python packages
     - `bindep.txt` for system packages
   - Version pin all dependencies for reproducibility

4. Security Measures:
   - Implement container scanning in build pipeline
   - Regular base image updates
   - Credentials management via environment variables
   - No hardcoded secrets

5. Testing Strategy:
   - Container-based testing scripts
   - Integration tests with AAP
   - Syntax validation
   - Security scanning

## Consequences

### Positive
- Consistent, reproducible builds
- Clear dependency management
- Secure by default
- Easy to maintain and update
- Integrated testing
- Compatible with Red Hat Ansible Automation Platform

### Negative
- Requires Red Hat subscriptions for base images
- Additional complexity in build process
- Learning curve for team members
- Storage overhead from container images
- Regular maintenance required for security updates

## Alternatives Considered

1. **Custom Base Image**
   - More control over base layer
   - Higher maintenance burden
   - Less standardization
   - Rejected due to support requirements

2. **Docker Compose Based Setup**
   - Familiar to many developers
   - Less integrated with Ansible ecosystem
   - Missing AAP-specific features
   - Rejected for enterprise compatibility

3. **Podman-Only Approach**
   - Simpler architecture
   - Missing build standardization
   - More manual steps
   - Rejected for scalability reasons

## References

- [Ansible Builder Documentation](https://ansible-builder.readthedocs.io/)
- [Red Hat Ansible Automation Platform Documentation](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform)
- [Container Security Best Practices](https://docs.openshift.com/container-platform/4.13/security/container_security/security-understanding.html)

## Notes

- Regular review of base image versions required
- Security scanning should be integrated into CI/CD pipeline
- Consider implementing automated dependency updates
- Document process for adding new dependencies 