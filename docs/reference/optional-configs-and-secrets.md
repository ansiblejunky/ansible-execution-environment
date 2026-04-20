---
title: Optional Configs and Secrets
description: How to use files/optional-configs for RHSM and oc installs, and keep secrets safe.
---

# Optional Configs and Secrets

This repository supports optional, opt-in configuration files placed under `files/optional-configs/` that modify the build behavior without changing `execution-environment.yml`.

## Directory

- `files/optional-configs/`
  - `rhsm-activation.env` (optional)
    - `RH_ORG=<org>`
    - `RH_ACT_KEY=<activation_key>`
    - Enables RHSM registration during build to install `openshift-clients` from Red Hat repos.
  - `oc-install.env` (optional)
    - `OC_VERSION=stable-4.21` or `v4.21.0`
    - `OC_URL=<full_tarball_url>` (optional override)
    - Installs `oc` and `kubectl` from mirror.openshift.com.

Both files are optional and can be used together or independently.

## Security and .gitignore

- `files/optional-configs/rhsm-activation.env` is ignored by git to prevent accidental commits.
- Store tokens (e.g., `ANSIBLE_HUB_TOKEN`) outside of the repo (e.g., local `token` file sourced into env).
- In CI, write these files at runtime from secrets rather than committing them.

## CI Usage Sketch

```yaml
- name: Prepare optional configs
  run: |
    mkdir -p files/optional-configs
    # RHSM (if using RPM path)
    if [ -n "${{ secrets.RH_ORG }}" ] && [ -n "${{ secrets.RH_ACT_KEY }}" ]; then
      cat > files/optional-configs/rhsm-activation.env <<EOF
RH_ORG=${{ secrets.RH_ORG }}
RH_ACT_KEY=${{ secrets.RH_ACT_KEY }}
EOF
    fi
    # oc/kubectl from tarball (recommended for CI)
    echo "OC_VERSION=stable-4.21" > files/optional-configs/oc-install.env
```

## When to Use Which

- Use RHSM env when you have entitlements and prefer RPM-managed `openshift-clients`.
- Use the tarball env when building in CI or environments without RHSM.

