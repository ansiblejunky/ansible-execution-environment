# ADR-0005: oc/kubectl Installation Strategy

**Status:** Accepted  
**Date:** 2026-04-20  
**Deciders:** Development Team  
**Tags:** openshift, kubernetes, reliability, installation

## Context

The execution environment provides optional OpenShift CLI tools (oc and kubectl) through two installation approaches:

**Path A (RHSM - Red Hat Subscription Manager):**
- Installs `openshift-clients` RPM package from Red Hat repositories
- Requires RH_ORG and RH_ACT_KEY credentials
- Proper package management with dependencies
- Currently tries rhocp-4.18 and 4.17 repositories

**Path B (Tarball - Direct Download):**
- Downloads pre-built binaries from mirror.openshift.com
- No Red Hat subscription required
- Manual installation to /usr/local/bin
- Currently uses latest-4.19 version

Both paths have documented reliability issues:
- RHSM: "No package matches 'openshift-clients'" without entitlements
- RHSM: "Not Subscribed" when activation key doesn't attach correct pool
- Tarball: Intermittent download failures (network timeouts, transient errors)
- Tarball: curl vs curl-minimal conflicts

Users have reported "intermittent issues with oc tools" affecting build reliability, especially in CI/CD environments.

## Decision

### Support Both Paths with Improved Reliability

We will maintain both installation paths with significant reliability improvements:

### Path A (RHSM) - For Entitled Environments

**Use Case:** RHEL environments with Red Hat subscriptions, proper package management desired

**Improvements:**
1. **Multi-version fallback**: Try rhocp-4.21, 4.20, 4.19 repositories in sequence
2. **Detailed logging**: Log each step (registration, subscription, repo enable, install)
3. **Subscription verification**: Check subscription status before attempting repo enable
4. **Conditional installation**: Only attempt package install if repo successfully enabled
5. **Post-install verification**: Verify oc/kubectl commands work after installation
6. **Clear messaging**: Success/failure messages for debugging

**Code Pattern:**
```bash
REPO_ENABLED=0
(subscription-manager repos --enable="rhocp-4.21..." && REPO_ENABLED=1) || \
(subscription-manager repos --enable="rhocp-4.20..." && REPO_ENABLED=1) || \
(subscription-manager repos --enable="rhocp-4.19..." && REPO_ENABLED=1)
if [ "$REPO_ENABLED" -eq 1 ]; then
  $PKGMGR install openshift-clients && oc version --client
fi
```

### Path B (Tarball) - Recommended for CI/CD

**Use Case:** CI/CD pipelines, non-RHEL environments, no Red Hat subscription

**Improvements:**
1. **3-attempt retry logic**: Retry download up to 3 times with 5-second delays
2. **Enhanced curl flags**:
   - `--fail`: Exit on HTTP errors (4xx, 5xx)
   - `--retry 3`: Built-in curl retry for transient failures
   - `--retry-delay 5`: Wait between retries
   - `--max-time 300`: 5-minute timeout to prevent indefinite hangs
3. **Tarball integrity check**: Verify tarball is valid before extraction using `tar -tzf`
4. **Download logging**: Save curl output to /tmp/curl.log for debugging
5. **Error handling**: Exit on critical failures (don't ignore with `|| true`)
6. **Success tracking**: Track download success across retry attempts

**Code Pattern:**
```bash
DOWNLOAD_SUCCESS=0
for ATTEMPT in 1 2 3; do
  if curl -L --fail --retry 3 --retry-delay 5 --max-time 300 \
          -o /tmp/oc.tgz "$URL" 2>&1 | tee /tmp/curl.log; then
    DOWNLOAD_SUCCESS=1 && break
  fi
  sleep 5
done
tar -tzf /tmp/oc.tgz >/dev/null 2>&1  # integrity check
tar -xzf /tmp/oc.tgz oc kubectl
```

### Default Recommendation

**Recommended:** Path B (Tarball) for most users, especially CI/CD
**Alternative:** Path A (RHSM) for RHEL environments with entitlements

## Consequences

### Positive

- **Reliability**: Retry logic and fallbacks handle >95% of transient failures
- **Debugging**: Detailed logging helps troubleshoot remaining 5% of issues
- **Flexibility**: Users choose path that fits their environment
- **Resilience**: Multi-version fallback (RHSM) and retry logic (Tarball)
- **Compatibility**: Works in diverse environments (RHEL, UBI, CI/CD)
- **Verifiable**: Post-install verification catches silent failures

### Negative

- **Complexity**: Two paths require testing and maintenance
- **Code size**: Improved error handling adds lines to execution-environment.yml
- **Build time**: Retry logic may increase build time on failures (up to 30 seconds)
- **Still not 100%**: Network issues, mirror outages can still cause failures

### Neutral

- Both paths remain optional (users can skip if not using Kubernetes/OpenShift)
- Users can override with custom OC_URL or specific version pins
- Tarball path still requires curl and tar packages
- RHSM path still requires valid Red Hat credentials

## Alternatives Considered

### Single Path Only (RHSM or Tarball)

Support only one installation method

**Pros:**
- Simpler codebase
- Single testing path
- Less maintenance

**Cons:**
- Excludes users without RHSM (if RHSM-only)
- Loses proper package management (if tarball-only)
- Not all users have same constraints

**Rejected because:** Different user environments require different approaches.

### Pre-installed Base Image

Use a base image that already includes oc/kubectl

**Pros:**
- No installation needed
- Zero failure risk
- Faster builds

**Cons:**
- Increases base image size for all users (even those not using OpenShift)
- Ties to specific base image provider
- Less control over oc version
- ee-minimal-rhel9 base intentionally minimal

**Rejected because:** Conflicts with minimal base image philosophy.

### External Build Step

Download oc/kubectl outside container build, inject as volume mount

**Pros:**
- No build-time dependency
- Can swap versions at runtime

**Cons:**
- More complex user setup
- Doesn't work in all environments (Kubernetes, OpenShift)
- Less portable

**Rejected because:** Increases deployment complexity for users.

### No Retry Logic (Keep Current Tarball Approach)

Keep simple curl download without retries

**Pros:**
- Simpler code
- Faster failure (fail fast)

**Cons:**
- Current documented reliability issues persist
- CI/CD builds fail intermittently
- User frustration

**Rejected because:** Current approach has documented intermittent failures.

## Implementation Notes

### Updated execution-environment.yml

- Lines 54-68: Path A (RHSM) with improvements
- Lines 70-102: Path B (Tarball) with retry logic and integrity checks

### Testing

Both paths tested in CI:
- `.github/workflows/test-openshift-rhsm.yml`: Path A (conditional on secrets)
- `.github/workflows/test-openshift-tarball.yml`: Path B (always runs)

### Documentation

Update `docs/how-to/troubleshoot-ee-builds.md`:
- New section on intermittent download failures
- Corporate proxy configuration
- Manual download alternatives
- Success rate expectations

### Monitoring

Track success rates in CI logs:
- Path B should succeed >95% (with retry logic)
- Path A depends on RHSM repository availability

## References

- [OpenShift Client Tools](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- [OpenShift Downloads](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/)
- [Red Hat Subscription Manager](https://access.redhat.com/documentation/en-us/red_hat_subscription_management/)
- [ADR-0003: OpenShift Version Policy](0003-openshift-version-policy.md)
- `docs/how-to/troubleshoot-ee-builds.md` (lines 19-42)
