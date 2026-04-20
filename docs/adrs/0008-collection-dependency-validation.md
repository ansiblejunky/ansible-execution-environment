# ADR-0008: Collection Dependency Validation

**Status:** Accepted  
**Date:** 2026-04-20  
**Deciders:** Development Team  
**Related:** ADR-0007 (AAP Collection Dependencies), ADR-0005 (oc/kubectl Installation Strategy)

## Context

Several Ansible collections require OpenShift CLI tools (`oc`/`kubectl`) as runtime dependencies, but this requirement is not obvious from their names and is only discovered when playbooks fail at runtime with "command not found" errors.

### Problem Statement

**Current State:**
- Collections like `kubernetes.core` require `oc`/`kubectl` binaries
- Collections like `ansible.platform` pull `kubernetes.core` as a dependency
- Users can uncomment these collections in `requirements.yml` without enabling OpenShift tooling
- Build succeeds (collections install fine)
- **Runtime failure** occurs when playbooks execute and can't find `oc`/`kubectl`
- Error messages are cryptic: "oc: command not found" with no clear path to resolution

**Impact:**
- **Poor User Experience**: Build succeeds but runtime fails
- **Time Wasted**: Users debug playbook failures instead of build configuration
- **Documentation Burden**: Users must read ADR-0007 to understand the dependency chain
- **Silent Failures**: No warning during build that dependencies are missing

### Collections Requiring OpenShift Tooling

**Direct Requirements (explicitly need oc/kubectl):**
- `kubernetes.core` - Kubernetes automation modules
- `redhat.openshift` - OpenShift-specific modules

**Transitive Requirements (pull kubernetes.core as dependency):**
- `ansible.platform` - AAP infrastructure management
- `ansible.eda` - Event-Driven Ansible (may pull kubernetes.core)

**Collections That May Enable in Future:**
- `redhat_cop.aap_utilities` - AAP utilities
- `infra.aap_configuration` - AAP configuration as code

## Decision

We will implement **automated dependency validation** that:

1. **Pre-Build Validation**: Check `requirements.yml` for collections that require OpenShift tooling
2. **Clear Error Messages**: If required collections are enabled but tooling is not, fail fast with actionable guidance
3. **Make Target**: Provide `make validate-deps` target that users can run manually
4. **Build Integration**: Run validation automatically as part of `make build` workflow
5. **Documentation**: Generate clear error messages pointing to configuration steps

### Validation Rules

**Rule 1: OpenShift Tooling Required Collections**
```yaml
# If ANY of these collections are uncommented in requirements.yml:
- kubernetes.core
- redhat.openshift
- ansible.platform
- ansible.eda

# THEN files/optional-configs/oc-install.env MUST exist
```

**Rule 2: Clear Error Message**
```
ERROR: Collection dependency validation failed!

The following collections require OpenShift CLI tools (oc/kubectl):
  - kubernetes.core (uncommented in requirements.yml)
  - ansible.platform (uncommented in requirements.yml)

OpenShift tooling is not configured.

To fix this:
  1. Create files/optional-configs/oc-install.env with:
     OC_VERSION=stable-4.21

  2. Rebuild with OpenShift support:
     make build-openshift-tarball

Or remove these collections from requirements.yml if not needed.

See ADR-0007 for details: docs/adrs/0007-aap-collection-dependencies.md
```

### Implementation Approach

**Script Location:** `scripts/validate-collection-deps.sh`

**Script Logic:**
1. Parse `requirements.yml` for collection names
2. Check if any collections match the "requires OpenShift tooling" list
3. If matches found, verify `files/optional-configs/oc-install.env` exists
4. Exit 0 if valid, exit 1 with clear error message if invalid

**Makefile Integration:**
```makefile
.PHONY: validate-deps
validate-deps:
	@echo "Validating collection dependencies..."
	@./scripts/validate-collection-deps.sh

# Add validation to build targets
build: validate-deps setup-ansible-cfg
	# ... existing build logic

build-openshift-tarball: validate-deps setup-openshift-tarball
	# ... existing build logic
```

**Optional: Warning Mode**
- Add `STRICT_VALIDATION=true` environment variable
- Default: warnings only (don't fail build)
- When `STRICT_VALIDATION=true`: fail build on validation errors
- Allows gradual adoption without breaking existing workflows

## Consequences

### Positive

- **Fail Fast**: Errors caught at build time, not runtime
- **Clear Guidance**: Error messages tell users exactly what to do
- **Better UX**: No mysterious "command not found" errors during playbook execution
- **Self-Documenting**: Validation logic serves as living documentation of dependencies
- **CI/CD Safety**: Prevents builds that will fail at runtime
- **Onboarding**: New users understand dependency requirements immediately

### Negative

- **Build Time Overhead**: Adds ~1-2 seconds to each build for validation
- **Maintenance**: Must update validation script when new collections are added
- **False Positives**: Edge cases where collections might work without oc/kubectl (rare)
- **Breaking Change**: Existing builds might fail if validation is strict by default

### Neutral

- **Optional Collections**: Users can still comment out collections to skip validation
- **Manual Override**: Advanced users can skip validation with `make build SKIP_VALIDATION=true`

## Implementation Plan

### Phase 1: Create Validation Script (Immediate)

1. Create `scripts/validate-collection-deps.sh`
2. Implement collection parsing logic
3. Implement dependency checking logic
4. Write clear error messages
5. Test with various `requirements.yml` configurations

### Phase 2: Integrate with Makefile (Immediate)

1. Add `validate-deps` target to Makefile
2. Add validation to `build`, `build-openshift-tarball`, `build-openshift-rhsm` targets
3. Add `STRICT_VALIDATION` environment variable support
4. Add `SKIP_VALIDATION` environment variable for override
5. Test build workflows

### Phase 3: Documentation Updates (Immediate)

1. Update README.md with validation information
2. Update troubleshooting guide with common validation errors
3. Update getting-started guide with validation section
4. Update RELEASE_TASKS.md to test validation

### Phase 4: CI/CD Integration (Phase 3)

1. Add validation to GitHub Actions workflows
2. Test that workflows fail appropriately with clear messages
3. Verify error messages are visible in GitHub Actions logs

## Testing Strategy

### Test Cases

**Test 1: Valid Configuration (Collections + Tooling)**
- `requirements.yml` has `kubernetes.core` uncommented
- `files/optional-configs/oc-install.env` exists
- Expected: Validation passes ✓

**Test 2: Valid Configuration (No Collections)**
- `requirements.yml` has all OpenShift collections commented out
- `files/optional-configs/oc-install.env` does NOT exist
- Expected: Validation passes ✓

**Test 3: Invalid Configuration (Collections without Tooling)**
- `requirements.yml` has `kubernetes.core` uncommented
- `files/optional-configs/oc-install.env` does NOT exist
- Expected: Validation fails with clear error message ✗

**Test 4: Edge Case (Transitive Dependency)**
- `requirements.yml` has `ansible.platform` uncommented (pulls kubernetes.core)
- `files/optional-configs/oc-install.env` does NOT exist
- Expected: Validation fails (detect transitive dependencies) ✗

**Test 5: Warning Mode**
- Invalid configuration
- `STRICT_VALIDATION=false` (default)
- Expected: Warning printed, build continues ⚠

**Test 6: Skip Validation**
- Invalid configuration
- `SKIP_VALIDATION=true`
- Expected: No validation, build continues

## Configuration

### Environment Variables

```bash
# Strict validation mode (fail build on errors)
export STRICT_VALIDATION=true  # Default: false (warnings only)

# Skip validation entirely (advanced users)
export SKIP_VALIDATION=true    # Default: false

# Validation verbosity
export VALIDATION_VERBOSE=true # Default: false (show detailed checks)
```

### Validation Configuration File (Future)

Consider adding `.validation-config.yml` in future:
```yaml
# Optional: Override which collections require OpenShift tooling
openshift_required_collections:
  - kubernetes.core
  - redhat.openshift
  - ansible.platform
  - ansible.eda
  - custom.my_collection  # User-defined

# Optional: Set default validation behavior
strict_mode: false
skip_validation: false
```

## Future Enhancements

1. **Dependency Graph Analysis**: Parse collection metadata to detect transitive dependencies automatically
2. **Python Package Validation**: Check that Python packages required by collections are in `requirements.txt`
3. **System Package Validation**: Check that system packages required by collections are in `bindep.txt`
4. **Version Compatibility**: Validate that collection versions are compatible with ansible-core version
5. **Collection Metadata Cache**: Cache collection dependency data to speed up validation

## References

- **ADR-0007**: AAP Collection Dependencies (context for this ADR)
- **ADR-0005**: oc/kubectl Installation Strategy (how to configure OpenShift tooling)
- **kubernetes.core Collection**: https://docs.ansible.com/ansible/latest/collections/kubernetes/core/
- **ansible.platform Collection**: https://console.redhat.com/ansible/automation-hub (certified content)
- **Ansible Collection Metadata**: https://docs.ansible.com/ansible/latest/dev_guide/collections_galaxy_meta.html

## Revision History

- **2026-04-20**: Initial decision for automated collection dependency validation
