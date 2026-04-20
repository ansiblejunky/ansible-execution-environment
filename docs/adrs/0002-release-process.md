# ADR-0002: Release Process and Tooling

**Status:** Accepted  
**Date:** 2026-04-20  
**Deciders:** Development Team  
**Tags:** releases, automation, changelog, process

## Context

The repository lacks a formal release process. There is no CHANGELOG, no GitHub Releases, and no documented procedure for creating and publishing releases. Users have no visibility into what changed between versions or how to track upcoming features.

We need an automated, repeatable release process that:
- Generates human-readable changelogs
- Creates GitHub Releases with release notes
- Publishes versioned container images to Quay.io
- Links changes to architectural decisions (ADRs)

## Decision

We will use the **ADR MCP `release_tracking` tool** with **Keep-a-Changelog** format for release management and changelog generation.

### Release Workflow

1. **Development**: Work proceeds on `main` branch using conventional commit messages (feat:, fix:, docs:)
2. **Pre-release**: Generate/update CHANGELOG.md using ADR MCP tool
3. **Tagging**: Create and push semantic version tag (e.g., `git tag v1.1.0 && git push origin v1.1.0`)
4. **Automation**: GitHub Actions workflow:
   - Builds container image
   - Runs test suite
   - Publishes image to Quay.io with version tag and `:latest`
   - Extracts relevant CHANGELOG section
   - Creates GitHub Release with notes
5. **Post-release**: Monitor for issues, merge dependabot PRs, plan next release

### CHANGELOG.md Format

Generated in [Keep-a-Changelog](https://keepachangelog.com/) format:

```markdown
## [Unreleased]

### Added
- New features

### Changed
- Changes to existing functionality

### Fixed
- Bug fixes

## [1.1.0] - 2026-04-25

### Added
- ADR framework...
```

### ADR MCP Tool Operations

```bash
# Track a release
mcp__adr-analysis__release_tracking operation=track_release version=v1.1.0 writeToFile=true

# Generate CHANGELOG
mcp__adr-analysis__release_tracking operation=generate_changelog \
  writeToFile=true format=keep-a-changelog groupByAdr=true includeAdrLinks=true

# Create milestone
mcp__adr-analysis__release_tracking operation=create_milestone \
  milestoneTitle="v1.2.0" milestoneDueDate="2026-06-15"
```

## Consequences

### Positive

- Automated CHANGELOG generation reduces manual work
- Changes are grouped by type (Added, Changed, Fixed, etc.)
- Links to ADRs provide architectural context
- Keep-a-Changelog format is industry standard and human-friendly
- GitHub Releases provide visibility to users
- CI/CD automation ensures consistent release process
- Release history is preserved in git tags and CHANGELOG.md

### Negative

- Depends on ADR MCP tool availability (mitigation: CHANGELOG is markdown, can be manually edited)
- Requires discipline to write good commit messages
- CHANGELOG must be kept in sync with actual releases

### Neutral

- CHANGELOG.md becomes source of truth for release notes
- Release cadence is not prescribed (as-needed releases)
- Both manual and automated release workflows are supported

## Alternatives Considered

### GitHub Auto-Generated Release Notes

Use GitHub's built-in release notes from PR titles

**Pros:**
- No external tools required
- Automatic from PR merge

**Cons:**
- No link to ADRs
- Less control over formatting
- Doesn't create CHANGELOG.md file
- Less human-friendly grouping

**Rejected because:** We want CHANGELOG.md in repo and ADR integration.

### Manual CHANGELOG Maintenance

Hand-write CHANGELOG.md for each release

**Pros:**
- Full control over content
- No tool dependencies

**Cons:**
- Error-prone and time-consuming
- Inconsistent formatting
- Easy to forget entries

**Rejected because:** Automation reduces errors and effort.

### Conventional Changelog Tool

Use conventional-changelog or similar tools based on commit messages

**Pros:**
- Well-established tooling
- Direct from commits

**Cons:**
- No ADR integration
- Requires commit message discipline
- Less semantic grouping

**Rejected because:** ADR MCP tool provides better integration with our architecture documentation.

## Implementation Notes

### GitHub Actions Integration

Update `.github/workflows/build-and-push.yml`:

```yaml
- name: Create GitHub Release
  if: startsWith(github.ref, 'refs/tags/v')
  env:
    GH_TOKEN: ${{ github.token }}
  run: |
    VERSION=${GITHUB_REF#refs/tags/}
    sed -n "/## \[$VERSION\]/,/## \[/p" CHANGELOG.md | sed '1d;$d' > release-notes.md
    gh release create "$VERSION" --title "Release $VERSION" \
      --notes-file release-notes.md --verify-tag
```

### Release Documentation

Create `docs/how-to/release-process.md` documenting:
- Version numbering guidelines (from ADR-0001)
- Tag creation procedure
- CHANGELOG update process
- Testing requirements
- Rollback procedures

## References

- [Keep a Changelog](https://keepachangelog.com/)
- [ADR-0001: Adopt Semantic Versioning](0001-adopt-semantic-versioning.md)
- [Conventional Commits](https://www.conventionalcommits.org/)
