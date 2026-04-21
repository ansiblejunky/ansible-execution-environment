---
title: Make Targets and Variables
description: Reference for Makefile targets, environment variables, and common usage.
---

# Make Targets and Variables

The Makefile orchestrates build, test, and publish tasks.

## Targets

- `setup` — **NEW:** Verify development environment setup and provide installation guidance.
  - Checks for required system packages (`podman`, `python3`, `git`, `jq`, `envsubst`)
  - Validates Python version (requires 3.10+ for `ansible-navigator`)
  - Detects and recommends Python 3.11/3.12 if available
  - Checks for Ansible Automation Platform tools (`ansible-builder`, `ansible-navigator`, `ansible-core`)
  - Provides RHEL-specific RPM installation instructions when applicable
  - **Insight:** Run this first before building to catch environment issues early
- `clean` — remove build artifacts and prune images.
- `lint` — run yamllint.
- `token` — render `ansible.cfg` from template and pre-fetch collections (validates `ANSIBLE_HUB_TOKEN`).
- `build` — build the EE via `ansible-builder`.
  - **Note:** Requires `ANSIBLE_HUB_TOKEN` environment variable for certified collections
  - **Note:** Requires login to `registry.redhat.io` to pull base image
- `inspect` — `podman inspect` the built image.
- `list` — list the built image (`podman images --filter reference=...`).
- `info` — show layers, Ansible version, collections, pip packages, rpm list.
- `test` — run `files/playbook.yml` via `ansible-navigator` using the built image.
  - **Note:** Uses `--pull-policy never` to use locally built images, preventing registry connection errors
  - **Note:** Does not require `ANSIBLE_HUB_TOKEN` (token only needed for build)
- `publish` — tag and push to `TARGET_HUB`.
- `shell` — open a shell in the image.
- `docs-setup`/`docs-build`/`docs-serve`/`docs-test` — local docs workflows.
- `setup-openshift-tarball` — setup Path B (tarball) configuration.
- `build-openshift-tarball` — build with Path B (tarball install).
- `test-openshift-tarball` — build and test Path B.
- `setup-openshift-rhsm` — setup Path A (RHSM) configuration.
- `build-openshift-rhsm` — build with Path A (RHSM/RPM install).
- `test-openshift-rhsm` — build and test Path A.
- `test-openshift-tooling` — test OpenShift/Kubernetes tooling in built image.

## Variables

- `TARGET_NAME` — image name (default: `ansible-ee-minimal`).
- `TARGET_TAG` — image tag (default: `v5`).
- `CONTAINER_ENGINE` — container runtime (default: `podman`).
- `VERBOSITY` — ansible-builder verbosity level (default: `3`).
- `TARGET_HUB` — registry for `publish` (default: `quay.io`).

Environment requirements:
- `ANSIBLE_HUB_TOKEN` — required for `build` and `token` targets; used to access Automation Hub/validated content.
  - **Insight:** Token check is performed at execution time, not parse time. This allows targets like `test`, `setup`, `lint` to run without requiring the token.
  - **Note:** The token is only needed when building images that include certified collections from Red Hat Automation Hub.

## Common Invocations

```bash
# First-time setup: Verify environment
make setup

# Clean rebuild
make clean build

# Build with explicit container engine and tag
CONTAINER_ENGINE=podman TARGET_TAG=v5 make build

# Build then test (test doesn't require ANSIBLE_HUB_TOKEN)
make build test

# Test without building (if image already exists)
make test

# Publish to quay.io/your-namespace
TARGET_HUB=quay.io TARGET_NAME=your-namespace/ansible-ee make publish
```

## Key Insights

### Token Requirements
- **Build and token targets require `ANSIBLE_HUB_TOKEN`** — These targets need to authenticate with Red Hat Automation Hub.
- **Test, setup, lint targets don't require token** — These can run independently without authentication.
- **GitHub Actions workflows:** Set `ANSIBLE_HUB_TOKEN` as a secret and pass it via `env:` for build steps only.

### Image Pull Policy
- The `test` target uses `--pull-policy never` to ensure it uses locally built images.
- This prevents errors when `ansible-navigator` tries to pull from a registry that doesn't have your image.
- **Insight:** Always test locally built images before pushing to registries.

### Python Version Requirements
- `ansible-navigator` requires Python 3.10 or later.
- On RHEL 9, Python 3.9 is the default, but Python 3.11 is available via `python3.11` package.
- **Recommendation:** Install Python 3.11+ for best compatibility: `sudo dnf install -y python3.11 python3.11-pip`
- The `setup` target detects and recommends the appropriate Python version.

### System Dependencies
- The minimal base image (`ee-minimal-rhel9`) doesn't include `python3-pip` by default.
- **Required:** Add `python3-pip` to `files/bindep.txt` for pip to be available during builds.
- See [Troubleshoot EE Builds](../how-to/troubleshoot-ee-builds.md) for the "No module named pip" error solution.

## Optional Config Flows

### OpenShift/Kubernetes Tooling

The project supports two paths for installing OpenShift/Kubernetes tooling, tested separately to avoid conflicts:

**Path A — RHSM/RPM install (requires RHSM entitlements):**
```bash
# Create files/optional-configs/rhsm-activation.env with RH_ORG and RH_ACT_KEY
make setup-openshift-rhsm build-openshift-rhsm
# Or test it all at once:
make test-openshift-rhsm
```

**Path B — Tarball install (no RHSM required):**
```bash
# Automatically creates files/optional-configs/oc-install.env
make setup-openshift-tarball build-openshift-tarball
# Or test it all at once:
make test-openshift-tarball
```

**Test existing image:**
```bash
make test-openshift-tooling
```

See the [Enable Kubernetes and OpenShift Tooling](../how-to/enable-kubernetes-openshift.md) guide for details on the two-phase testing approach.
