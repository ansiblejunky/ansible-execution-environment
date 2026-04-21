---
title: Why Keep execution-environment.yml Minimal
description: Rationale and common pitfalls when customizing execution-environment.yml for ansible-builder.
---

# Why Keep execution-environment.yml Minimal

This repository intentionally keeps `execution-environment.yml` small and declarative. Most customizations live in separate dependency files under `files/`. This approach reduces merge conflicts, makes reviews easier, and avoids brittle builds.

## Design Rationale

- Separation of concerns: collections, Python, and system packages are defined in their own files (`requirements.yml`, `requirements.txt`, `bindep.txt`).
- Repeatability: minimal inline steps and explicit files enable deterministic builds across hosts and CI.
- Maintainability: small diffs when changing dependencies; easier to audit and roll back.

## How ansible-builder Uses It

- Reads `dependencies` to produce a build context and containerfile.
- Executes `additional_build_steps` in well-defined phases: `prepend_base`, `prepend_galaxy`, `append_final`.
- Stages `additional_build_files` into `_build/` for COPY operations inside steps.

## Common Pitfalls to Avoid

- Overwriting the entire file with unrelated templates. Instead, add/edit only the specific sections you need.
- Inlining long dependency lists directly in YAML. Always reference files in `files/` to keep changes scoped and testable.
- Baking secrets into the YAML. Use environment variables (e.g., `ANSIBLE_HUB_TOKEN`) and mounted configs.
- Adding heavyweight tooling by default. Keep optional tools commented and document the trade-offs in docs.

## Safe Extension Patterns

- Need extra preinstall steps? Add a short, idempotent line in `prepend_base` and verify with `make build test`.
- Need a different base image? Change `images.base_image`, then validate with `make info` and `make inspect`.
- Need private mirrors? Add the relevant config file to the repo, reference it under `additional_build_files`, then COPY it in `prepend_galaxy`.

## Verification

Before opening a PR:
- `make lint build test` locally.
- Include the produced image tag, sample commands used, and a short `make test` output snippet.

