---
title: execution-environment.yml Reference
description: Field-by-field reference and best practices for version 3 EE definitions used by ansible-builder.
---

# execution-environment.yml Reference

This document explains every key section in this repository’s `execution-environment.yml` and documents how `ansible-builder` consumes it. Follow these conventions to avoid fragile builds and accidental overrides.

Important guidelines for this repo:
- Keep `execution-environment.yml` minimal and declarative.
- Put dependencies in `files/requirements.yml`, `files/requirements.txt`, and `files/bindep.txt` — not inline.
- Use `additional_build_steps` only for targeted, repeatable steps.
- Use `make lint build test` to validate changes locally.

## Version

```yaml
version: 3
```
- Uses the `ansible-builder` v3 schema. Earlier schemas differ in structure and feature support.

## Build Args Defaults

```yaml
build_arg_defaults:
  ANSIBLE_GALAXY_CLI_COLLECTION_OPTS: '--ignore-certs'
```
- Sets defaults for build-time args passed to the underlying containerfile.
- `ANSIBLE_GALAXY_CLI_COLLECTION_OPTS` tunes `ansible-galaxy collection install` behavior during the build.

## Dependencies

```yaml
dependencies:
  galaxy: files/requirements.yml
  python: files/requirements.txt
  system: files/bindep.txt
```
- The canonical place for all content dependencies.
- Do not inline dependencies here; point to files in `files/` instead per repo guidelines.
  - `galaxy`: Collections to install via `ansible-galaxy` (supports private/certified content when `ANSIBLE_HUB_TOKEN` is set).
  - `python`: Pip requirements for collections/playbooks not already declared by the collections themselves.
  - `system`: OS packages installed using the image package manager (declared via bindep format).

## Base Image

```yaml
images:
  base_image:
    name: 'registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest'
```
- The starting image for the EE. Swap to a supported alternative when needed (e.g., `ee-supported-rhel9`).
- Verify after changes with `make info` and `make inspect`.

## Options

```yaml
options:
  package_manager_path: /usr/bin/microdnf
```
- Explicitly controls which package manager is used during the build.
- Keep aligned with the chosen base image (RHEL/UBI images use `microdnf`).

## Additional Build Files

```yaml
additional_build_files:
  - src: ansible.cfg
    dest: configs
  - src: files/optional-configs
    dest: configs/optional
  - src: scripts/install-from-bindep
    dest: scripts
  - src: scripts/assemble
    dest: scripts
```
- Stages files into the build context under `_build/` and makes them available to copy during steps.
- In this repo, `ansible.cfg` is required so `ansible-galaxy` behaves consistently inside the build.
- The `files/optional-configs` folder holds optional env files used by build steps:
  - `rhsm-activation.env`: `RH_ORG` and `RH_ACT_KEY` for enabling the OpenShift client repo (RPM path).
  - `oc-install.env`: `OC_VERSION` (or `OC_URL`) to install `oc`/`kubectl` from tarball (no RHSM).
- We also override builder helper scripts (`install-from-bindep`, `assemble`) to filter the `openshift-clients` RPM when using the tarball path. Review these overrides when upgrading ansible-builder.

## Additional Build Steps

```yaml
additional_build_steps:
  prepend_base:
    - RUN whoami
    - RUN cat /etc/os-release
    - RUN echo PKGMGR = $PKGMGR, PYCMD = $PYCMD
    - RUN $PYCMD -m pip install --upgrade pip
    - COPY _build/configs/optional /_extras/optional
  prepend_galaxy:
    - COPY _build/configs/ansible.cfg /etc/ansible/ansible.cfg
    # Optional: RHSM registration to install openshift-clients via RPM if entitlements exist
    - >
      RUN RH_ENV="/_extras/optional/rhsm-activation.env" ; \
          if [ -f "$RH_ENV" ]; then set -a; . "$RH_ENV"; set +a; fi ; \
          if [ -n "$RH_ORG" ] && [ -n "$RH_ACT_KEY" ]; then \
            (command -v subscription-manager >/dev/null 2>&1 || $PKGMGR -y install subscription-manager || true) && \
            subscription-manager register --org="$RH_ORG" --activationkey="$RH_ACT_KEY" && \
            subscription-manager attach --auto || true && \
            ARCH=$(uname -m) && \
            (subscription-manager repos --enable="rhocp-4.15-for-rhel-9-${ARCH}-rpms" || \
             subscription-manager repos --enable="rhocp-4.14-for-rhel-9-${ARCH}-rpms" || true) && \
            ($PKGMGR -y install openshift-clients || true) ; \
          fi

    # Optional: Tarball install of oc/kubectl (repo-free)
    - >
      RUN OC_ENV="/_extras/optional/oc-install.env" ; \
          if [ -f "$OC_ENV" ]; then set -a; . "$OC_ENV"; set +a; fi ; \
          if [ -n "$OC_URL" ] || [ -n "$OC_VERSION" ]; then \
            URL="${OC_URL:-https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux.tar.gz}" && \
            ($PKGMGR -y install curl tar || true) && \
            curl -L -o /tmp/oc.tgz "$URL" && \
            tar -C /usr/local/bin -xzf /tmp/oc.tgz oc kubectl && \
            chmod +x /usr/local/bin/oc /usr/local/bin/kubectl && \
            rm -f /tmp/oc.tgz ; \
          fi

  append_final:
    - RUN pip3 check
    - >
      RUN if command -v subscription-manager >/dev/null 2>&1; then \
            subscription-manager unregister || true && \
            subscription-manager clean || true && \
            rm -f /etc/yum.repos.d/redhat.repo && \
            rm -rf /etc/rhsm/* ; \
          fi
    - >
      RUN $PKGMGR update -y &&
      $PKGMGR clean all &&
      rm -rf /var/cache/{dnf,yum} &&
      rm -rf /var/lib/dnf/history.* &&
      rm -rf /var/log/*
```
- `prepend_base`: Runs before dependency resolution; good for bootstrapping tools and environment sanity checks.
- `prepend_galaxy`: Runs immediately before `ansible-galaxy` steps; used here to enforce the `ansible.cfg` inside the build.
- `append_final`: Runs after everything is installed; used for validation (`pip3 check`) and cleanup to reduce image size.

Notes and tips:
- Keep steps idempotent and fast; avoid long-running curl scripts or interactive steps.
- When adding optional tooling (e.g., azure-cli, packer), gate them behind commented examples and document trade-offs.

## Environment and Tokens

- `ANSIBLE_HUB_TOKEN` should be exported in your shell to access Red Hat Automation Hub certified content during builds.
- For private mirrors or proxies, customize `ansible.cfg` or add repo configs via `additional_build_files` + `additional_build_steps`.
- Optional env files:
  - `files/optional-configs/rhsm-activation.env` to install `openshift-clients` via RPM.
  - `files/optional-configs/oc-install.env` to install `oc`/`kubectl` from a tarball.

## What Not To Do

- Do not replace `execution-environment.yml` wholesale. Extend via the files referenced above and minimal edits.
- Do not inline large dependency lists here; keep `files/requirements*.{yml,txt}` authoritative.
- Do not hardcode registry credentials or secrets; pass them as environment variables or mount config files at build time.

## Verification Checklist

- `make lint` passes and YAML formatting follows repo guidelines (2-space indents, lowercase keys, `*.yml`).
- `make token` confirms `ANSIBLE_HUB_TOKEN` (if needed) and pre-fetches collections.
- `make build` succeeds on a machine with `podman` and `ansible-builder` installed.
- `make test` runs `files/playbook.yml` successfully via `ansible-navigator`.
- If Kubernetes/OpenShift collections are enabled: `oc version --client` works in the image; `kubernetes.core` appears in `ansible-navigator collections`.
