---
title: Enable Kubernetes and OpenShift Tooling
description: Two supported paths to include kubernetes.core/redhat.openshift collections and oc/kubectl in your EE.
---

# Enable Kubernetes and OpenShift Tooling

This guide shows how to enable Kubernetes/OpenShift modules and include the `oc`/`kubectl` CLIs in your Execution Environment (EE).

Supported approaches:
- Path A (RPM via RHSM): enable Red Hat repos and install `openshift-clients` via RPM.
- Path B (Tarball, no RHSM): install `oc`/`kubectl` from the official tarball and bypass the RPM dependency.

## Prerequisites

- Working local build per the Build Locally guide.
- Optional RHSM entitlements for Path A.

## Step 1: Choose your path

### Path A — RPM install (requires RHSM entitlements)

Use this if you can attach an OpenShift client repo subscription during build.

1) Create `files/optional-configs/rhsm-activation.env` with your org/key:

```
RH_ORG=<your_org>
RH_ACT_KEY=<your_activation_key>
```

2) **Optional**: Uncomment collections in `files/requirements.yml` if you need Ansible modules:

```
# containers
- name: kubernetes.core
# - name: redhat.openshift
```

**Note**: The `oc`/`kubectl` binaries are installed independently via `execution-environment.yml`. Collections are optional and provide Ansible modules that use the binaries.

3) Build:

```
export ANSIBLE_HUB_TOKEN=$(cat token)
make build
```

What happens:
- The build registers with RHSM, attempts auto-attach, enables an `rhocp-4.15` or `4.14` repo (by arch), and installs `openshift-clients`.
- On cleanup, RHSM registration is removed.

Notes:
- Your activation key must attach a subscription that includes the OpenShift client repo. If not, the repo enable step is skipped.
- **Collections are optional**: You can use `oc`/`kubectl` binaries without installing `kubernetes.core` or `redhat.openshift` collections.

### Path B — Tarball install (no RHSM required)

Use this if you do not have RHSM entitlements or want a simpler, portable build.

1) Create `files/optional-configs/oc-install.env` with a pinned version:

```
# Tracks latest in the 4.21 stream; or pin to an exact tag like v4.21.0
OC_VERSION=stable-4.21
```

2) **Optional**: Uncomment collections in `files/requirements.yml` if you need Ansible modules:

```
# containers
- name: kubernetes.core
# - name: redhat.openshift
```

**Note**: The `oc`/`kubectl` binaries are installed independently via `execution-environment.yml`. Collections are optional and provide Ansible modules that use the binaries.

3) Build:

```
export ANSIBLE_HUB_TOKEN=$(cat token)
make build
```

What happens:
- The build downloads `openshift-client-linux.tar.gz` from mirror.openshift.com for the requested version and installs `oc` and `kubectl` into `/usr/local/bin`.
- Symlinks are created in `/usr/bin` for compatibility with Ansible modules and tools that expect binaries in the standard location.
- The EE intentionally filters the `openshift-clients` RPM from bindep to avoid failing without RHSM.

**Insight:** The symlinks ensure maximum compatibility - binaries are installed in `/usr/local/bin` (standard for tarball installs) but also accessible via `/usr/bin` (expected by some Ansible modules).

Notes:
- **Collections are optional**: You can use `oc`/`kubectl` binaries without installing `kubernetes.core` or `redhat.openshift` collections.

## Step 2: Verify

```bash
# Check if binaries exist (minimal images may not have 'which' command)
podman run --rm ansible-ee-minimal:v5 test -f /usr/local/bin/oc && echo "✓ oc found"
podman run --rm ansible-ee-minimal:v5 test -f /usr/bin/oc && echo "✓ oc symlink found"
podman run --rm ansible-ee-minimal:v5 /usr/local/bin/oc version --client
podman run --rm ansible-ee-minimal:v5 /usr/local/bin/kubectl version --client

# Or use the test script
make test-openshift-tooling

# Check collections (if installed)
ansible-navigator collections --mode stdout --pull-policy never --eei ansible-ee-minimal:v5 | grep kubernetes.core
```

**Note:** The test script (`scripts/test-openshift-tooling.sh`) uses `test -f` instead of `which` since minimal base images don't include the `which` command. This makes testing more reliable across different image types.

## Step 3: Two-Phase Testing

To ensure consistency and avoid conflicts between the two installation paths, the project uses a two-phase testing approach:

### Phase 1: Test Path B (Tarball - No RHSM Required)

This phase tests the tarball installation method, which works without RHSM credentials:

```bash
# Build and test Path B
export ANSIBLE_HUB_TOKEN=$(cat token)
make test-openshift-tarball
```

Or manually:
```bash
# Setup Path B configuration
make setup-openshift-tarball
# Build
make build-openshift-tarball
# Test
make test-openshift-tooling
```

### Phase 2: Test Path A (RHSM/RPM - Requires Credentials)

This phase tests the RPM installation method via RHSM:

```bash
# First, create files/optional-configs/rhsm-activation.env with:
# RH_ORG=<your_org>
# RH_ACT_KEY=<your_activation_key>

# Then build and test Path A
export ANSIBLE_HUB_TOKEN=$(cat token)
make test-openshift-rhsm
```

Or manually:
```bash
# Setup Path A configuration (requires rhsm-activation.env)
make setup-openshift-rhsm
# Build
make build-openshift-rhsm
# Test
make test-openshift-tooling
```

### Automated Testing in CI/CD

The GitHub Actions workflow (`.github/workflows/test-openshift.yml`) automatically runs both phases:

- **Phase 1** always runs and tests the tarball installation
- **Phase 2** runs only if `RH_ORG` and `RH_ACT_KEY` secrets are configured in GitHub

This ensures:
- Both paths are tested independently
- No conflicts between `oc-install.env` and `rhsm-activation.env`
- Consistent, reproducible builds for each path

### Testing Script

The project includes a dedicated test script (`scripts/test-openshift-tooling.sh`) that verifies:

1. `oc` and `kubectl` binaries exist and are executable (checks `/usr/local/bin` and `/usr/bin`)
2. Version commands work correctly
3. `kubernetes.core` collection is installed (if configured)
4. Binary permissions are correct

**Key implementation details:**
- Uses `test -f` instead of `which` command (minimal images don't include `which`)
- Checks both `/usr/local/bin` and `/usr/bin` for maximum compatibility
- Uses `--pull-policy never` when calling `ansible-navigator` to ensure local images are used

You can run it directly:
```bash
scripts/test-openshift-tooling.sh ansible-ee-minimal:v5 podman
```

## Troubleshooting

- Missing `openshift-clients` error during build:
  - Path A: your activation key didn’t attach an OCP entitlement; add an attach pool or use Path B.
  - Path B: ensure `files/optional-configs/oc-install.env` exists and is valid; rebuild.
- Corporate proxies: export `HTTP_PROXY`/`HTTPS_PROXY` for the build, or configure `additional_build_steps` to set them.

## Notes and Best Practices

- Pin `OC_VERSION` to your cluster’s major/minor (e.g., `v4.21.0`) for reproducibility.
- If you later adopt RHSM RPM install, remove `oc-install.env` to avoid duplicate installs.
- Upgrading ansible-builder: we override the builder’s `assemble`/`install-from-bindep` via `additional_build_files` to filter `openshift-clients`. Review these overrides when changing ansible-builder versions.

