---
title: Build Locally with Makefile and Podman
description: Step-by-step guide to build and test the EE locally using podman and the project Makefile.
---

# Build Locally with Makefile and Podman

This guide shows how to build and test the Execution Environment (EE) fully on your machine. It uses `podman` as the container engine and the provided `Makefile` targets to keep commands consistent.

## Prerequisites

- `podman` installed and working (`podman --version`).
- `ansible-builder` and `ansible-navigator` installed.
- Optional for certified/private content: export `ANSIBLE_HUB_TOKEN`.

**Recommendation:** Run `make setup` first to verify your environment and get installation guidance if needed.

## Quick Start

```bash
# From the repo root
make setup           # Verify environment setup (NEW - recommended first step)
make lint            # yamllint checks
make token           # verifies ANSIBLE_HUB_TOKEN and pre-fetches collections
make build           # builds the EE image via ansible-builder
make list            # validate the image tag exists locally
make test            # runs files/playbook.yml inside the built image
```

## Environment Overrides

- `CONTAINER_ENGINE` defaults to `podman`. Example: `CONTAINER_ENGINE=podman make build`.
- `TARGET_NAME` and `TARGET_TAG` control the build tag. Example:

```bash
CONTAINER_ENGINE=podman TARGET_NAME=ansible-ee-minimal TARGET_TAG=v5 make build test
```

## Inspect and Debug

```bash
make info            # layers, versions, packages summary
make inspect         # container metadata via podman/inspect
make shell           # open a shell inside the image for manual checks
```

## Troubleshooting

- **Environment setup:** Run `make setup` to check for missing tools and get installation instructions.
- **Token issues:** 
  - `ANSIBLE_HUB_TOKEN` is only required for `make build` and `make token` targets.
  - The `make test` target doesn't require the token (uses locally built image).
  - Ensure token is exported before `make token build`.
- **"No module named pip" error:** 
  - The minimal base image doesn't include `python3-pip` by default.
  - **Solution:** Add `python3-pip [platform:rpm]` to `files/bindep.txt`.
  - See [Troubleshoot EE Builds](troubleshoot-ee-builds.md) for details.
- **Python version issues:** 
  - `ansible-navigator` requires Python 3.10+.
  - On RHEL 9, install Python 3.11: `sudo dnf install -y python3.11 python3.11-pip`
  - The `make setup` target will detect and recommend the correct Python version.
- **Network-restricted builds:** Add internal mirrors in `ansible.cfg` and copy via `additional_build_files` + `additional_build_steps`.
- **Dependency errors:** Use `make shell` then run `pip check`, and validate system packages listed in `files/bindep.txt`.
- **Fast validation:** `ansible-navigator run files/playbook.yml --syntax-check --mode stdout`.
- **Image pull errors during test:** The `make test` target uses `--pull-policy never` to prevent registry connection errors. Ensure your image is built locally first.

## Do and Don’t

- Do edit dependencies in `files/requirements.yml`, `files/requirements.txt`, and `files/bindep.txt`.
- Don’t overwrite `execution-environment.yml`; keep it minimal and declarative.
