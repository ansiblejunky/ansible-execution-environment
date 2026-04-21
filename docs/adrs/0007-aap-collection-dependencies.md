# ADR-0007: Ansible Automation Platform Collection Dependencies and OpenShift Tooling

**Status:** Accepted  
**Date:** 2026-04-20  
**Deciders:** Development Team  
**Related:** ADR-0005 (oc/kubectl Installation Strategy), ADR-0003 (OpenShift Version Policy)

## Context

This execution environment is designed to support Ansible Automation Platform (AAP) workflows, including collections that manage AAP infrastructure itself. Several AAP collections have dependencies on OpenShift tooling that are not immediately obvious from their names.

### AAP Collection Dependency Chain

**Active Collections:**
- `ansible.hub` - Automation Hub management
- `ansible.controller` - Automation Controller management
- `amazon.aws` - AWS cloud automation
- `azure.azcollection` - Azure cloud automation

**Available (Currently Commented) AAP Collections:**
- `ansible.platform` - **REQUIRES openshift-clients** (pulls `kubernetes.core`)
- `ansible.eda` - Event-Driven Ansible (may pull `kubernetes.core`)
- `redhat_cop.aap_utilities` - AAP utilities
- `infra.aap_configuration` - AAP configuration as code

**Container Management Collections (Commented):**
- `kubernetes.core` - **REQUIRES oc/kubectl CLI tools**
- `redhat.openshift` - OpenShift-specific modules

### The Hidden Dependency Problem

The `ansible.platform` collection is used for managing Ansible Automation Platform infrastructure. When installed, it:
1. Automatically pulls `kubernetes.core` as a dependency
2. `kubernetes.core` modules require `oc` and/or `kubectl` CLI binaries
3. Without the binaries, playbooks fail at runtime with "oc: command not found"

This creates a **runtime dependency** that must be satisfied at build time, even if not all users will manage Kubernetes/OpenShift resources.

### Testing Results

**Path A (RHSM) Testing (2026-04-20):**
- ✅ Works on bare metal RHEL with active subscription
- ❌ **FAILS in ansible-builder (containerized builds)**
- Root cause: `subscription-manager` detects container mode and disables registration
- Error: "subscription-manager is operating in container mode. Use your host system to manage subscriptions."
- Nested container limitation: ansible-builder creates containers during build; these don't inherit host subscriptions
- **Conclusion:** Not viable for CI/CD or containerized build pipelines

**Path B (Tarball) Testing (2026-04-20):**
- ✅ Works in all environments (local, CI/CD, containerized builds)
- ✅ Successfully installed OpenShift 4.21.9
- ✅ Retry logic handles intermittent download failures
- ✅ Integrity checks validate downloaded tarballs
- ✅ No subscription or entitlement requirements
- **Conclusion:** Recommended for all use cases

## Decision

We will **maintain OpenShift tooling support in this execution environment** to enable:

1. **AAP Collection Compatibility**: Allow users to enable `ansible.platform` and related collections without build failures
2. **Container Management**: Support `kubernetes.core` and `redhat.openshift` collections for users managing containerized workloads
3. **Flexibility**: Provide both RHSM (Path A) and tarball (Path B) installation methods, with Path B as the recommended default

**Primary Method:** Path B (Tarball)
- Documented in ADR-0005
- Works in all environments
- Current version: OpenShift 4.21 (stable-4.21 channel)
- Update policy: ADR-0003 (within 30 days of new releases)

**Secondary Method:** Path A (RHSM)
- Available for bare metal RHEL builds only
- **Not viable for ansible-builder/containerized builds**
- Documented for completeness but not recommended

**Default Configuration:**
- OpenShift tooling installation is **OPTIONAL** (requires explicit opt-in)
- Users enable by creating `files/optional-configs/oc-install.env`
- Collections like `kubernetes.core` are commented out by default
- Users uncomment collections as needed for their use cases

## Consequences

### Positive

- **AAP Collection Support**: Users can enable `ansible.platform` and related collections without manual intervention
- **Clear Documentation**: Dependency chain explicitly documented for troubleshooting
- **Flexible Installation**: Both paths available based on environment constraints
- **CI/CD Compatible**: Path B works in GitHub Actions, GitLab CI, Jenkins, etc.
- **Version Currency**: OpenShift 4.21 provides latest features and security updates

### Negative

- **Image Size**: Including oc/kubectl adds ~45MB to the execution environment (when enabled)
- **Maintenance Overhead**: Must track OpenShift releases and update within 30 days per ADR-0003
- **Path A Limitation**: RHSM path documented but not usable in most CI/CD scenarios
- **Optional Complexity**: Users must understand when to enable OpenShift tooling

### Neutral

- **Runtime Dependencies**: Collections that require oc/kubectl will still fail if tooling not installed, but failure is clear and actionable
- **Testing Burden**: Must test both installation paths when making changes to build process

## Implementation Notes

### For Users Enabling AAP Platform Collections

If you need to use `ansible.platform` or similar collections:

1. **Enable OpenShift tooling (Path B - Recommended):**
   ```bash
   # Create configuration file
   echo "OC_VERSION=stable-4.21" > files/optional-configs/oc-install.env
   
   # Build with OpenShift support
   make build-openshift-tarball
   ```

2. **Uncomment required collections:**
   ```yaml
   # files/requirements.yml
   collections:
     - name: ansible.platform  # Pulls kubernetes.core
     - name: kubernetes.core   # Explicitly include if needed
   ```

3. **Verify installation:**
   ```bash
   podman run --rm <image> oc version --client
   # Expected: Client Version: 4.21.x
   ```

### For Bare Metal RHEL Builds (Path A)

If building on a subscribed RHEL system (not using ansible-builder):
1. Create `files/optional-configs/rhsm-activation.env` with RH_ORG and RH_ACT_KEY
2. Use `make build-openshift-rhsm`
3. **Note:** This does NOT work with ansible-builder containerized builds

### Build Process Changes

When OpenShift tooling is enabled:
- Build time increases by ~2-3 minutes (tarball download + extraction)
- Retry logic handles transient network failures (3 attempts with 5s delays)
- Tarball integrity verification prevents corrupted installations
- Binaries installed to `/usr/local/bin/` with symlinks in `/usr/bin/`

## References

- **AAP Certified Collections**: https://access.redhat.com/support/articles/ansible-automation-platform-certified-content
- **Complete Collection List**: https://access.redhat.com/articles/3642632
- **Automation Hub**: https://console.redhat.com/ansible/automation-hub
- **kubernetes.core Collection**: https://docs.ansible.com/ansible/latest/collections/kubernetes/core/
- **OpenShift Client Tools**: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/
- **subscription-manager Container Mode Issue**: https://bugzilla.redhat.com/show_bug.cgi?id=1114132

## Revision History

- **2026-04-20**: Initial decision documenting AAP collection dependencies and OpenShift tooling rationale
