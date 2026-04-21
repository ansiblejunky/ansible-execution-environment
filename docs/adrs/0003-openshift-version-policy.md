# ADR-0003: OpenShift Version Policy

**Status:** Accepted  
**Date:** 2026-04-20  
**Deciders:** Development Team  
**Tags:** openshift, kubernetes, dependencies, maintenance

## Context

The execution environment includes optional OpenShift CLI tools (oc/kubectl) that can be installed via two paths:
- **Path A (RHSM)**: RPM package via Red Hat Subscription Manager
- **Path B (Tarball)**: Direct download from mirror.openshift.com

Currently, the repository references OpenShift 4.19, but OpenShift 4.21 is the latest stable release. We need a policy for:
- Which OpenShift version to support
- How quickly to update when new versions are released
- Whether to support multiple versions simultaneously
- Testing requirements before updates

Without a clear policy, version updates are ad-hoc and may lag significantly behind current releases, potentially causing compatibility and security issues.

## Decision

### Version Support Policy

1. **Single Version Support**: Support only the latest stable OpenShift minor version
2. **Update Timeline**: Update within 30 days of a new minor release (e.g., 4.21 → 4.22)
3. **Testing Requirement**: Test both installation paths (RHSM + tarball) before releasing updates
4. **Fallback Strategy**: RHSM path tries current and two previous minor versions (e.g., 4.21, 4.20, 4.19)
5. **Version Increments**: OpenShift updates trigger MINOR version bumps (e.g., v1.1.0 → v1.2.0)

### Current Version

- **OpenShift**: 4.21 (stable)
- **Update Date**: 2026-04-20 (v1.1.0)
- **Next Review**: When OpenShift 4.22 is released

### Update Process

1. **Detection**: Monitor https://mirror.openshift.com/pub/openshift-v4/clients/ocp/ for new stable releases
2. **Testing**: Test both installation paths in development
3. **Update Files**: Update version references across codebase (see file list below)
4. **CI Validation**: Verify all GitHub Actions workflows pass
5. **Documentation**: Update CHANGELOG and release notes
6. **Release**: Tag new MINOR version

### Files Requiring Updates

When updating OpenShift versions, modify these files:

- `execution-environment.yml` (RHSM repo versions, tarball comments)
- `.github/workflows/test-openshift-tarball.yml` (OC_VERSION)
- `Makefile` (default OC_VERSION)
- `docs/how-to/enable-kubernetes-openshift.md` (examples)
- `docs/how-to/troubleshoot-ee-builds.md` (examples)
- `docs/reference/optional-configs-and-secrets.md` (examples)
- `docs/tutorials/getting-started.md` (examples)
- `README.md` (version references)

Verify: `grep -r "4\.XX" docs/` should show only current version

## Consequences

### Positive

- Clear expectations for users about supported versions
- Timely security updates and bug fixes
- Reduced maintenance burden (single version)
- Users can pin to older EE versions if needed (via container tags)
- 30-day window allows for proper testing
- Fallback repos (4.21, 4.20, 4.19) provide resilience for RHSM path

### Negative

- Users on older OpenShift clusters may need to use older EE versions
- MINOR version bumps for OpenShift updates may be more frequent than desired
- No multi-version support increases upgrade pressure on users
- Requires monitoring OpenShift release schedule

### Neutral

- OpenShift typically releases minor versions quarterly (manageable update cadence)
- Breaking change only when dropping version support (MAJOR bump)
- Tarball path allows pinning to specific versions (e.g., `OC_VERSION=v4.19.6`)

## Alternatives Considered

### Support Multiple OpenShift Versions

Maintain compatibility with last 2-3 minor versions

**Pros:**
- More flexible for users
- Less pressure to upgrade

**Cons:**
- Increased testing matrix (2-3x effort)
- More complex documentation
- Harder to troubleshoot issues
- Unclear which version is "default"

**Rejected because:** Single version simplifies maintenance without significant user impact.

### Immediate Updates (No 30-day Window)

Update to new OpenShift versions immediately upon release

**Pros:**
- Always latest features
- Minimal lag

**Cons:**
- New releases may have bugs
- Insufficient time for testing
- May break users unexpectedly

**Rejected because:** 30-day window allows for proper testing and stability.

### Quarterly Update Schedule

Update OpenShift versions on fixed schedule (regardless of releases)

**Pros:**
- Predictable updates
- Easier planning

**Cons:**
- May lag behind important security fixes
- Doesn't align with OpenShift release cadence
- Arbitrary delay if OpenShift releases early/late

**Rejected because:** Event-driven (30 days from release) is more responsive.

### No Version Policy

Update versions ad-hoc as needed

**Pros:**
- Flexibility
- No process overhead

**Cons:**
- Unpredictable for users
- May lag significantly
- Inconsistent approach

**Rejected because:** Current ad-hoc approach has led to version lag (4.19 while 4.21 is current).

## Implementation Notes

### First Update (v1.1.0)

- Update from OpenShift 4.19 → 4.21
- RHSM path tries: 4.21 → 4.20 → 4.19
- Tarball path uses: stable-4.21
- Testing: Both paths validated in CI

### Future Updates

- Monitor OpenShift release announcements
- Set calendar reminder for 30 days after new stable release
- Use ADR MCP tool to plan release milestone
- Follow standard release process (ADR-0002)

### Exception Process

If critical security vulnerability requires immediate update:
- Skip 30-day window
- Expedite testing
- Tag PATCH release if no breaking changes
- Document exception in CHANGELOG

## References

- [OpenShift Release Notes](https://docs.openshift.com/container-platform/latest/release_notes/ocp-4-release-notes.html)
- [OpenShift Client Downloads](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/)
- [ADR-0001: Adopt Semantic Versioning](0001-adopt-semantic-versioning.md)
- [ADR-0005: oc/kubectl Installation Strategy](0005-oc-installation-strategy.md)
