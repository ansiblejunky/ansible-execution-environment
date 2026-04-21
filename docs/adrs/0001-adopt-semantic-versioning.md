# ADR-0001: Adopt Semantic Versioning

**Status:** Accepted  
**Date:** 2026-04-20  
**Deciders:** Development Team  
**Tags:** versioning, releases, process

## Context

The repository currently uses an arbitrary tagging scheme (e.g., `v5` as default in Makefile) that doesn't convey meaningful information about the nature or impact of changes. There is no CHANGELOG, no formal release process, and no way for users to understand what has changed between versions.

As the project matures and gains users, we need a clear, predictable versioning strategy that communicates the scope and impact of changes.

## Decision

We will adopt [Semantic Versioning 2.0.0](https://semver.org/) for all releases starting with v1.0.0.

Version numbers will follow the format: MAJOR.MINOR.PATCH

- **MAJOR**: Incremented for incompatible API changes or breaking changes (e.g., dropping Python version support, removing features, incompatible base image changes)
- **MINOR**: Incremented for new functionality in a backward-compatible manner (e.g., OpenShift version updates, new optional features, new collections)
- **PATCH**: Incremented for backward-compatible bug fixes (e.g., documentation fixes, build script improvements, security patches)

### Initial Releases

- **v1.0.0**: Baseline release representing the current stable state (no functional changes from current main)
- **v1.1.0**: First feature release including OpenShift 4.21 update, dependabot, and reliability improvements

## Consequences

### Positive

- Users can understand the impact of upgrading by examining version numbers
- Breaking changes are clearly signaled by MAJOR version increments
- Compatible with automated dependency management tools (dependabot)
- Industry-standard approach familiar to most users
- Enables automated CHANGELOG generation tools
- Clear upgrade path and rollback strategy

### Negative

- Requires discipline to maintain version numbers correctly
- First MAJOR version (v1.0.0) may imply more stability than warranted
- Must carefully consider what constitutes a "breaking change" for a container image

### Neutral

- Existing Makefile default tag (`v5`) will be updated but users can override
- Git tags become the source of truth for versions
- Previous informal versioning approach is superseded

## Alternatives Considered

### Calendar Versioning (CalVer)

Format: YYYY.MM.PATCH (e.g., 2026.04.0)

**Pros:**
- Immediately shows age of release
- Works well for frequently released projects

**Cons:**
- Doesn't convey scope of changes
- Less familiar to users expecting semantic versioning
- Doesn't integrate as well with dependency management tools

**Rejected because:** Semantic meaning of changes is more valuable than release date for a container image project.

### Continue with Arbitrary Tags

Keep current system with manually incremented tags (v6, v7, etc.)

**Pros:**
- No process changes required
- Simple incrementing scheme

**Cons:**
- No information about scope of changes
- Doesn't integrate with modern tooling
- Unprofessional for production use

**Rejected because:** Doesn't meet the needs of a maturing project with external users.

## References

- [Semantic Versioning 2.0.0](https://semver.org/)
- [ADR-0002: Release Process and Tooling](0002-release-process.md)
- [Keep a Changelog](https://keepachangelog.com/)
