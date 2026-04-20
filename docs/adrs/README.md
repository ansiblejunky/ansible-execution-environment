# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records (ADRs) for the ansible-execution-environment project.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences.

## When to Write an ADR

Create an ADR when you make a significant architectural decision that:
- Affects the structure, dependencies, or behavior of the project
- Involves trade-offs between different approaches
- Will impact future development or users
- Needs to be documented for future reference

Examples:
- Choosing a versioning scheme
- Adopting a new tool or framework
- Changing build or deployment processes
- Major dependency updates or changes

## ADR Format

Each ADR follows this structure:

```markdown
# ADR-NNNN: Title

**Status:** [Proposed | Accepted | Deprecated | Superseded]  
**Date:** YYYY-MM-DD  
**Deciders:** [List of people involved]  
**Tags:** [relevant, tags]

## Context

What is the issue or situation we're addressing?

## Decision

What is the change we're making?

## Consequences

What becomes easier or harder as a result?

## Alternatives Considered

What other options did we evaluate?

## References

Links to related documents, ADRs, or external resources
```

## ADR Lifecycle

1. **Proposed**: ADR is drafted and under discussion
2. **Accepted**: ADR is approved and decision is implemented
3. **Deprecated**: ADR is no longer relevant but kept for historical context
4. **Superseded**: ADR is replaced by a newer ADR (link to replacement)

## Existing ADRs

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](0001-adopt-semantic-versioning.md) | Adopt Semantic Versioning | Accepted | 2026-04-20 |
| [0002](0002-release-process.md) | Release Process and Tooling | Accepted | 2026-04-20 |
| [0003](0003-openshift-version-policy.md) | OpenShift Version Policy | Accepted | 2026-04-20 |
| [0004](0004-dependency-management.md) | Dependency Management Strategy | Accepted | 2026-04-20 |
| [0005](0005-oc-installation-strategy.md) | oc/kubectl Installation Strategy | Accepted | 2026-04-20 |

## Creating a New ADR

1. Copy `template.md` to a new file with the next number (e.g., `0006-my-decision.md`)
2. Fill in the template sections
3. Submit as a pull request for review
4. Update this README with the new ADR entry
5. Move status to "Accepted" once approved and implemented

## References

- [ADR GitHub Organization](https://adr.github.io/)
- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) by Michael Nygard
