# ADR-0004: Dependency Management Strategy

**Status:** Accepted  
**Date:** 2026-04-20  
**Deciders:** Development Team  
**Tags:** dependencies, security, automation, maintenance

## Context

The execution environment has dependencies across multiple ecosystems:
- **GitHub Actions** workflows (8 workflows using various actions)
- **Container base image** (RHEL 9 minimal from Red Hat registry)
- **Python packages** (pip, setuptools, ara in `files/requirements.txt`)
- **Ansible collections** (ansible.hub, ansible.controller, AWS, Azure, community in `files/requirements.yml`)
- **System packages** (dnf, git, jq, curl, etc. in `files/bindep.txt`)

Currently, all dependencies are updated manually, leading to:
- Security vulnerabilities remaining unpatched
- Outdated dependencies causing compatibility issues
- Inconsistent update cadence
- Maintenance burden on developers

We need an automated approach to keep dependencies current while maintaining stability.

## Decision

Implement **Dependabot** for automated dependency updates with the following configuration:

### Scope

| Ecosystem | Update Frequency | Grouping | Commit Prefix |
|-----------|-----------------|----------|---------------|
| GitHub Actions | Weekly (Monday 9am) | Individual | `ci:` |
| Docker/Container | Monthly (Monday 9am) | Individual, ignore patch | `build:` |
| Python pip (files/) | Monthly (Monday 9am) | Group minor/patch | `build:` |
| Python pip (mkdocs) | Monthly (Monday 9am) | Individual | `docs:` |

### Manual Management (No Dependabot Support)

- **Ansible collections**: Monthly manual review of Red Hat Automation Hub
- **System packages**: Managed via base image updates (dependabot docker)

### Review Process

1. **Automated**: Dependabot creates PRs automatically
2. **CI Validation**: All GitHub Actions tests must pass
3. **Review**: Weekly batch review and merge (Mondays)
4. **Major Updates**: Require manual testing, may trigger MINOR version bump
5. **Breaking Changes**: Investigate thoroughly, update code/config as needed

### PR Labels

All dependabot PRs tagged with:
- `dependencies` (all)
- `github-actions` | `container` | `python` | `documentation` (ecosystem-specific)

### Ignore Rules

- Container base image: Ignore PATCH updates (too frequent, handled in monthly review)
- Python packages: Group minor/patch updates to reduce PR volume

## Consequences

### Positive

- Automated security vulnerability patching
- Reduced manual maintenance burden
- Consistent update cadence
- CI tests prevent breaking changes from merging
- Conventional commit prefixes maintain clean git history
- GitHub security alerts automatically resolved
- Audit trail via PR history

### Negative

- Weekly PR volume may be high initially (10-15 PRs/week possible)
- Breaking changes require investigation and fixes
- False positives (updates that break tests) require triage
- Dependabot doesn't understand domain-specific compatibility (e.g., Ansible collection dependencies)
- Manual process still required for Ansible collections

### Neutral

- Developers must review dependabot PRs weekly (recurring task)
- Major version updates may be deferred if breaking
- Can ignore specific dependencies if problematic
- Dependabot configuration itself requires maintenance

## Alternatives Considered

### Renovate Bot

Alternative dependency update bot with more features

**Pros:**
- More configuration options
- Better multi-language support
- Can handle Ansible Galaxy (with configuration)

**Cons:**
- More complex setup
- Requires third-party app installation
- Not natively integrated with GitHub
- Steeper learning curve

**Rejected because:** Dependabot is native to GitHub, simpler, and sufficient for our needs.

### Manual Updates Only

Continue current manual update process

**Pros:**
- Full control over timing
- No automation overhead
- No surprise PRs

**Cons:**
- Security vulnerabilities remain unpatched
- Inconsistent updates
- High maintenance burden
- Easy to forget/defer updates

**Rejected because:** Current approach has led to outdated dependencies and security gaps.

### Daily Dependabot Updates

Run dependabot daily instead of weekly/monthly

**Pros:**
- Faster security patches
- Smaller change sets

**Cons:**
- PR noise and fatigue
- Daily review burden
- May merge updates too quickly

**Rejected because:** Weekly/monthly cadence balances timeliness with review burden.

## Implementation Notes

### Dependabot Configuration

File: `.github/dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
    open-pull-requests-limit: 5
    labels: ["dependencies", "github-actions"]
    commit-message:
      prefix: "ci"

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "monthly"
    labels: ["dependencies", "container"]
    commit-message:
      prefix: "build"
    ignore:
      - dependency-name: "registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9"
        update-types: ["version-update:semver-patch"]

  - package-ecosystem: "pip"
    directory: "/files"
    schedule:
      interval: "monthly"
    labels: ["dependencies", "python"]
    commit-message:
      prefix: "build"
    groups:
      python-packages:
        patterns: ["*"]
        update-types: ["minor", "patch"]

  - package-ecosystem: "pip"
    directory: "/mkdocs.yml"
    schedule:
      interval: "monthly"
    labels: ["dependencies", "documentation"]
    commit-message:
      prefix: "docs"
```

### Ansible Collections Manual Process

1. **Monthly**: Review Red Hat Automation Hub for collection updates
2. **Check Changelogs**: Identify breaking changes
3. **Update**: Modify `files/requirements.yml` version constraints
4. **Test**: Full build and test cycle locally
5. **Document**: Note collection updates in CHANGELOG
6. **Release**: Include in next MINOR or PATCH release

### Future Considerations

- Custom GitHub Action to check Ansible collection updates
- Automated alerts for new collection versions
- Integration with Red Hat Automation Hub API (if available)

## References

- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [Dependabot Configuration Options](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file)
- [ADR-0002: Release Process and Tooling](0002-release-process.md)
