---
title: Release Process
description: How to create and publish releases for ansible-execution-environment
---

# Release Process

This document describes the release process for the ansible-execution-environment project.

## Overview

We use [Semantic Versioning](https://semver.org/) (MAJOR.MINOR.PATCH) and the ADR MCP `release_tracking` tool for managing releases.

- **Repository**: https://github.com/tosin2013/ansible-execution-environment
- **Container Registry**: quay.io/takinosh/ansible-execution-environment
- **CHANGELOG Format**: [Keep a Changelog](https://keepachangelog.com/)

## Release Types

- **MAJOR (X.0.0)**: Breaking changes (e.g., dropping Python version support, incompatible base image changes)
- **MINOR (x.X.0)**: New features, OpenShift version updates, new functionality in backward-compatible manner
- **PATCH (x.x.X)**: Bug fixes, documentation updates, security patches

## Prerequisites

Before creating a release:

1. **Security verification complete** (see [SECURITY_CHECKLIST.md](../../SECURITY_CHECKLIST.md))
   - No secrets in staged changes
   - No credentials in documentation
   - `.gitignore` protecting sensitive files
2. All tests passing on `main` branch
3. CHANGELOG.md reviewed and updated (can be auto-generated)
4. Version number decided according to semantic versioning
5. All documentation updated to reflect changes
6. ADRs created for any architectural decisions

## Release Workflow

### Step 1: Update CHANGELOG

Generate or update CHANGELOG.md using the ADR MCP tool:

```bash
# Generate CHANGELOG for all releases
mcp__adr-analysis__release_tracking \
  operation=generate_changelog \
  projectPath=/home/vpcuser/ansible-execution-environment \
  writeToFile=true \
  format=keep-a-changelog \
  groupByAdr=true \
  includeAdrLinks=true
```

Review the generated CHANGELOG and make any necessary manual edits.

### Step 2: Security Verification

**CRITICAL**: Before committing, verify no secrets are included:

```bash
# Check what's staged
git status

# Review all changes
git diff --cached

# Grep for potential secrets
git diff --cached | grep -i -E '(password|token|secret|key|api_key|auth|RH_ORG|RH_ACT_KEY|ANSIBLE_HUB_TOKEN|QUAY_)'

# Verify sensitive files are ignored
git check-ignore files/optional-configs/rhsm-activation.env
git check-ignore files/optional-configs/oc-install.env
git check-ignore token
```

If any secrets are found, remove them and update `.gitignore` if needed.

**See [SECURITY_CHECKLIST.md](../../SECURITY_CHECKLIST.md) for complete security verification steps.**

### Step 3: Commit CHANGELOG Updates

```bash
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for v1.1.0"
git push origin main
```

### Step 4: Create and Push Git Tag

```bash
# Create annotated tag
git tag -a v1.1.0 -m "Release v1.1.0: OpenShift 4.21, dependabot, improved reliability"

# Push tag to trigger CI/CD
git push origin v1.1.0
```

### Step 5: Automated CI/CD

GitHub Actions (`.github/workflows/build-and-push.yml`) automatically:

1. Builds container image using `ansible-builder`
2. Runs test suite (`make test`)
3. Publishes image to Quay.io:
   - `quay.io/takinosh/ansible-execution-environment:v1.1.0`
   - `quay.io/takinosh/ansible-execution-environment:latest` (for tags on main)
4. Extracts relevant CHANGELOG section
5. Creates GitHub Release with release notes

### Step 6: Verify Release

**Check GitHub Release:**
```bash
# View release on GitHub
https://github.com/tosin2013/ansible-execution-environment/releases/tag/v1.1.0
```

**Check Quay.io Image:**
```bash
# Pull and verify the image
podman pull quay.io/takinosh/ansible-execution-environment:v1.1.0
podman run --rm quay.io/takinosh/ansible-execution-environment:v1.1.0 ansible --version

# Verify OpenShift tools if applicable
podman run --rm quay.io/takinosh/ansible-execution-environment:v1.1.0 oc version --client
```

**Verify Image Tags:**
- Visit https://quay.io/repository/takinosh/ansible-execution-environment?tab=tags
- Confirm both version tag (e.g., `v1.1.0`) and `latest` are present

### Step 7: Announce Release

- Post announcement in relevant channels
- Update project README if needed
- Close related GitHub issues/milestones

## Manual Release (Alternative)

If automated CI/CD is not available, you can release manually:

### Build Image Locally

```bash
# Set version
export TARGET_TAG=v1.1.0

# Build
export ANSIBLE_HUB_TOKEN=$(cat token)
make clean
make build

# Test
make test

# Tag for Quay.io (adjust username if needed)
podman tag ansible-ee-minimal:$TARGET_TAG quay.io/takinosh/ansible-execution-environment:$TARGET_TAG
podman tag ansible-ee-minimal:$TARGET_TAG quay.io/takinosh/ansible-execution-environment:latest
```

### Publish to Quay.io

```bash
# Login to Quay.io
podman login quay.io

# Push images
podman push quay.io/takinosh/ansible-execution-environment:$TARGET_TAG
podman push quay.io/takinosh/ansible-execution-environment:latest
```

### Create GitHub Release

```bash
# Extract CHANGELOG for this version
VERSION=v1.1.0
sed -n "/## \[$VERSION\]/,/## \[/p" CHANGELOG.md | sed '1d;$d' > release-notes.md

# Create GitHub release using gh CLI
gh release create "$VERSION" \
  --title "Release $VERSION" \
  --notes-file release-notes.md \
  --verify-tag
```

## Rollback Procedures

### Option 1: Hotfix Patch Release

If a critical issue is found after release:

```bash
# Fix the issue on main
git commit -m "fix: critical issue description"

# Tag patch release
git tag v1.1.1
git push origin v1.1.1

# CI/CD automatically builds and publishes
```

### Option 2: Revert to Previous Version

Users can pull the previous version:

```bash
podman pull quay.io/takinosh/ansible-execution-environment:v1.0.0
```

Or update their workflows/documentation to reference the previous tag temporarily.

### Option 3: Update Latest Tag (Emergency Only)

Manually re-tag `latest` to point to a previous version:

```bash
# Pull previous version
podman pull quay.io/takinosh/ansible-execution-environment:v1.0.0

# Re-tag as latest
podman tag quay.io/takinosh/ansible-execution-environment:v1.0.0 \
  quay.io/takinosh/ansible-execution-environment:latest

# Push
podman login quay.io
podman push quay.io/takinosh/ansible-execution-environment:latest
```

## Release Checklist

### Pre-Release

- [ ] All tests passing on `main` branch
- [ ] CHANGELOG.md updated with changes for this version
- [ ] Version number follows semantic versioning
- [ ] Documentation updated (if applicable)
- [ ] ADRs created for architectural decisions (if applicable)
- [ ] OpenShift version tested (if updating)
- [ ] Breaking changes clearly documented

### Release

- [ ] CHANGELOG committed and pushed to main
- [ ] Git tag created with version (e.g., v1.1.0)
- [ ] Tag pushed to GitHub
- [ ] GitHub Actions completed successfully
- [ ] Container image published to Quay.io

### Post-Release

- [ ] GitHub Release created with notes from CHANGELOG
- [ ] Both version tag and `latest` visible on Quay.io
- [ ] Image pulls successfully: `podman pull quay.io/takinosh/ansible-execution-environment:v1.1.0`
- [ ] Tested basic functionality: `oc version --client` (if applicable)
- [ ] Announcement made (if applicable)
- [ ] GitHub milestone closed (if applicable)

## Release Schedule

- **Patch releases**: As needed for critical bugs
- **Minor releases**: Monthly or as features are completed
- **Major releases**: Only when breaking changes are necessary
- **OpenShift updates**: Within 30 days of new minor release (per [ADR-0003](../adrs/0003-openshift-version-policy.md))

## Monitoring Post-Release

### Week 1
- Monitor GitHub issues for bug reports
- Review first dependabot PRs
- Confirm CI/CD pipelines stable

### Month 1
- At least 3 dependabot PRs reviewed and merged
- No regression in build success rate
- Documentation confirmed accurate

## Questions?

- Review [ADR-0001: Semantic Versioning](../adrs/0001-adopt-semantic-versioning.md)
- Review [ADR-0002: Release Process and Tooling](../adrs/0002-release-process.md)
- Open an issue: https://github.com/tosin2013/ansible-execution-environment/issues
