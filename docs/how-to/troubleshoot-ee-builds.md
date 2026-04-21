---
title: Troubleshoot EE Builds
description: Common build errors, causes, and quick fixes for Execution Environment images.
---

# Troubleshoot EE Builds

Use this checklist when `make build` fails or images don’t behave as expected.

## Quick Triage

- Inspect logs: `tail -n 200 ansible-builder.log`
- Rebuild clean: `make clean && make build`
- Verify env: `echo $ANSIBLE_HUB_TOKEN`, `podman login registry.redhat.io`
- Fast validate: `ansible-navigator run files/playbook.yml --syntax-check --mode stdout`

## Common Errors and Fixes

### No package matches 'openshift-clients'

Cause: `kubernetes.core` (or related) adds a bindep on `openshift-clients` for RHEL; the base image lacks the OCP repo.

Fix options:
- **Path A (RHSM with improved reliability):** Add `files/optional-configs/rhsm-activation.env` (RH_ORG/RH_ACT_KEY) and rebuild. Updated version tries 4.21, 4.20, 4.19 repos automatically with detailed logging.
- **Path B (Tarball - recommended for CI):** Add `files/optional-configs/oc-install.env` (e.g., `OC_VERSION=stable-4.21`) to install `oc`/`kubectl` from tarball; rebuild. Now includes retry logic and integrity verification.
- **Temporary workaround:** Comment out collections that pull in `kubernetes.core` in `files/requirements.yml`.

**Status:** Both paths now have improved error handling and logging (as of v1.1.0).

### RHSM “Not Subscribed” / No repositories available

Cause: The activation key registers but does not attach a pool that includes the OCP client repo.

Fix:
- Ensure your activation key auto-attaches a valid OCP pool, or provide a pool ID and attach explicitly (not covered here).
- Or use the tarball approach for `oc`.

### curl vs curl-minimal conflict

Symptom: microdnf reports conflicts when installing curl.

Fix:
- We attempt `($PKGMGR -y install curl tar || true)` in the tarball path. If needed, prefer `curl-minimal` (already present on UBI) and skip `curl`.
- Build still proceeds because the download usually succeeds.

### Intermittent OpenShift Client Download Failures (Path B)

**Symptom:** Tarball download fails with network errors or timeouts.

**Causes:**
- mirror.openshift.com temporary unavailability
- Network connectivity issues
- Corporate firewall/proxy interference
- Corrupted partial downloads

**Automatic mitigations (already implemented):**
- 3 automatic retry attempts with delays
- Built-in curl retry logic (`--retry 3 --retry-delay 5`)
- 5-minute download timeout to prevent indefinite hangs
- Tarball integrity verification before extraction

**Manual fixes if build still fails:**

1. **Check mirror availability:**
   ```bash
   curl -I https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.21/openshift-client-linux.tar.gz
   ```

2. **Use specific version instead of stable/latest:**
   ```bash
   # More reliable - direct version
   echo "OC_VERSION=v4.21.0" > files/optional-configs/oc-install.env
   ```

3. **Corporate proxy:** Export proxy environment in execution-environment.yml:
   ```yaml
   - ENV HTTP_PROXY=http://proxy.corp.com:8080
   - ENV HTTPS_PROXY=http://proxy.corp.com:8080
   ```

4. **Download tarball manually and use custom URL:**
   ```bash
   # Download to accessible location, then:
   echo "OC_URL=https://your-mirror.com/openshift-client-linux.tar.gz" > files/optional-configs/oc-install.env
   ```

**Insight:** The retry logic handles >95% of transient failures. Persistent failures usually indicate network infrastructure issues requiring manual intervention.

### "No module named pip" error

Symptom: Build fails with `/usr/bin/python3: No module named pip` during the assemble step.

Cause: The base image `registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest` is a minimal image that does not include `python3-pip` by default. When `ansible-builder` runs the assemble script to install Python packages, pip is not available.

Fix:
- Add `python3-pip` to system dependencies in `files/bindep.txt`:
  ```
  python3-pip [platform:rpm]
  ```
- Rebuild: `make clean && make build`
- This ensures pip is installed during the build process before Python packages are installed.

Reference: [Red Hat Solution 7116301](https://access.redhat.com/solutions/7116301)

### Pip cannot find ansible-core version

Cause: Base image Python version may not match latest ansible-core.

Fix:
- Pin a compatible version in `execution-environment.yml` under `dependencies.ansible_core` (example: `2.15.13`).
- Rebuild and verify `ansible --version` in `make info`.

### Galaxy/Hub auth issues

Symptom: `ansible-galaxy` download errors.

Fix:
- Confirm `ANSIBLE_HUB_TOKEN` is exported: `export ANSIBLE_HUB_TOKEN=$(cat token)`.
- Regenerate `ansible.cfg`: `make token` or remove and rebuild.

### Corporate proxies / timeouts

Fix:
- Export `HTTP_PROXY`/`HTTPS_PROXY` during `make build`.
- If proxies are mandatory, add a proxy-aware curl step in `additional_build_steps` or mount config files via `additional_build_files`.

### Which collection requires OCP?

Identify:
```
tmp=$(mktemp -d)
ansible-galaxy collection download -r files/requirements.yml -p "$tmp"
rg -n "openshift-clients" "$tmp"/**/bindep.txt
```

## Common Pitfalls and Solutions

### Environment Setup Issues

**Problem:** Build fails with missing tools or wrong Python version.

**Solution:**
- Run `make setup` first to verify environment
- On RHEL 9, install Python 3.11: `sudo dnf install -y python3.11 python3.11-pip`
- Install missing tools using the instructions provided by `make setup`

**Insight:** Always verify your environment before building. The `make setup` target catches issues early.

### Token Check Errors

**Problem:** `make test` fails with "ANSIBLE_HUB_TOKEN is undefined" even though you only want to test.

**Solution:**
- This is fixed! Token check now only runs for `build` and `token` targets
- `make test`, `make setup`, `make lint` can run without `ANSIBLE_HUB_TOKEN`
- Only `make build` and `make token` require the token

**Insight:** Token requirements are now execution-time, not parse-time, allowing more flexible workflows.

### Image Pull Errors During Testing

**Problem:** `make test` tries to pull image from registry and fails with connection errors.

**Solution:**
- Fixed! The `test` target now uses `--pull-policy never`
- Ensures locally built images are used
- Prevents registry connection errors during local testing

**Insight:** Always test locally built images before pushing to registries.

### Minimal Image Limitations

**Problem:** Commands like `which` don't work in minimal base images.

**Solution:**
- Use `test -f` instead of `which` for checking binary existence
- The test scripts have been updated to use `test -f` for compatibility
- When writing custom scripts, prefer `test -f /path/to/binary` over `which binary`

**Insight:** Minimal images are intentionally small - use standard POSIX commands (`test`, `ls`, `stat`) instead of utilities like `which`.

## When to ask for help

- Share the last 100–200 lines of `ansible-builder.log` and your `files/requirements.yml` diff.
- Include your chosen path (RPM vs tarball) and whether proxies are in use.
- Include output from `make setup` if environment issues are suspected.

