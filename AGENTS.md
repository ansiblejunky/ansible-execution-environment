# Ansible Execution Environment (EE) Guidelines

## Project Overview
Ansible Execution Environments are containerized environments that package the dependencies needed to run Ansible automation, ensuring consistent execution across different systems.

## Project Structure &amp; Module Organization
- Root: `Makefile`, `execution-environment.yml`, `ansible-navigator.yml`.
- Dependencies: `files/requirements.yml` (collections), `files/requirements.txt` (Python), `files/bindep.txt` (system pkgs), plus sample `files/playbook.yml`.
- Docs: `docs/` (Diátaxis style: tutorials/how-to/reference/explanation) with `mkdocs.yml`.
- CI: `.github/workflows/yamllint.yml` for YAML linting.

## Quick Start
1. Clone the repository
2. Configure `ANSIBLE_HUB_TOKEN` environment variable
3. Run `make build` to build the EE
4. Run `make test` to validate the EE

## Build, Test, and Development Commands
- `make clean` — remove build artifacts and prune images.
- `make token` — verify `ANSIBLE_HUB_TOKEN` and pre-fetch collections.
- `make build` — build the EE image via `ansible-builder`.
- `make test` — run `files/playbook.yml` with `ansible-navigator` against the built image.
- `make inspect` — container metadata; `make info` — layers, versions, packages.
- `make publish` — push image to `TARGET_HUB`; `make shell` — open a shell in the image.
Environment: export `ANSIBLE_HUB_TOKEN`. Optional overrides: `TARGET_NAME`, `TARGET_TAG`, `CONTAINER_ENGINE` (podman), `TARGET_HUB`.
Example: `CONTAINER_ENGINE=podman TARGET_TAG=v5 make build test`.

## Coding Style &amp; Naming Conventions
- YAML: 2-space indent, no tabs, lowercase keys with hyphens; files end with `.yml`.
- Keep `execution-environment.yml` minimal; add deps to `files/*` instead of inline.
- Docs: concise Markdown; relative links under `docs/`.
- Make targets: lowercase, verbs (e.g., `build`, `test`).

## Testing Approach
- Lint: `make lint` (yamllint). CI runs on push/PR.
- Validate builds with `make test`; for fast checks use: `ansible-navigator run files/playbook.yml --syntax-check --mode stdout`.
- Prefer small, reversible changes; test with `podman` locally.

## Pull Request (PR) Guidelines
- Commits: short, imperative subject; include scope when helpful. Examples: `fix: update bindep openssl-devel`, `docs: clarify publish steps`.
- PRs include: description of change, rationale, sample command(s) used, image tag produced, and `make test` output snippet. Link related issues and update `docs/` when behavior changes.

## Security &amp; Configuration Guidelines
- Do not commit secrets (e.g., `ANSIBLE_HUB_TOKEN`, kubeconfigs). Use env vars and local config mounts.
- For private mirrors, adjust `ansible.cfg` and pip/yum config via `additional_build_steps` and mounted files.
- Use `podman` as the standard container engine in this repo and CI.

## Environment Variables
| Variable | Description | Default/Example |
|----------|-------------|-----------------|
| `ANSIBLE_HUB_TOKEN` | Token for Ansible automation hub | Required. Create at: https://console.redhat.com/ |
| `TARGET_NAME` | Name of target container image | `ansible-ee` |
| `TARGET_TAG` | Tag for target container image | `dev` |
| `CONTAINER_ENGINE` | Container engine to use | `podman` |
| `TARGET_HUB` | Target container registry | `docker.io` |

## Common Patterns
### Basic development workflow:
```bash
export ANSIBLE_HUB_TOKEN=your-token-here
make clean
make build
make test
```

### Podman-specific workflow:
```bash
CONTAINER_ENGINE=podman TARGET_TAG=v5 make clean build test
```

### Adding a new Python requirement:
1. Add to `files/requirements.txt`
2. Run `make lint build test`

### Adding a new Ansible collection:
1. Add to `files/requirements.yml`
2. Run `make token build test`

## Agent-Specific Instructions
- Scope: entire repo. Preserve file layout and target names.
- When adding dependencies, update `files/requirements*.{yml,txt}` and `files/bindep.txt` accordingly.
- Before opening a PR, run: `make lint build test`.

## Integration Patterns
### New Project Integration
1. Fork/clone the repository
2. Update `execution-environment.yml` with new project name
3. Add dependencies to `files/requirements.{yml,txt}` and `files/bindep.txt`
4. Create a `.github/workflows/ci.yml` file for your CI pipeline

### Existing Project Integration
1. Add this repository as a git submodule in your project: `git submodule add https://github.com/tosin2013/ansible-execution-environment.git ee`
2. Update `execution-environment.yml` with project name and custom dependencies
3. Copy Makefile to your project root: `cp ee/Makefile ./`
4. Configure your CI pipeline to use the updated Makefile

## Workflow Diagram
```
[Local Development]
        │
        v
[Build EE Image] --> [Test Image]
        │                   │
        v                   v
[Update Dependencies] <-- [Validate Tests]
        │                   │
        v                   v
[PR] --> [CI/CD Pipeline]
        │
        v
[Publish Image] --> [Deploy to Target Environment]
```

## Reference Index
### Documentation Structure (Diátaxis Style)
- Tutorials: Step-by-step guides for learning
  - Getting Started: `docs/tutorials/getting-started.md`
  - Building Locally: `docs/how-to/build-locally.md`
  - Testing: `docs/how-to/testing-execution-environment.md`
- How-to Guides: Recipes for specific tasks
  - Enable Kubernetes/OpenShift: `docs/how-to/enable-kubernetes-openshift.md`
  - Advanced Usage: `docs/how-to/advanced-usage.md`
- Reference: Technical information
  - Execution Environment YAML: `docs/reference/execution-environment-yaml.md`
  - Make Targets: `docs/reference/make-targets.md`
  - Optional Configs: `docs/reference/optional-configs-and-secrets.md`
- Explanation: Theory and concepts
  - Technology Stack: `docs/explanation/technology-stack.md`
  - Design Decisions: `docs/explanation/design-decisions.md`

### Key Components
| Component | Purpose | Reference |
|-----------|---------|-----------|
| `execution-environment.yml` | Defines the EE composition | `docs/reference/execution-environment-yaml.md` |
| `files/requirements.{yml,txt}` | Collections and Python dependencies | `docs/reference/execution-environment-yaml.md` |
| `files/bindep.txt` | System dependencies | `docs/reference/execution-environment-yaml.md` |
| Makefile | Build/deploy operations | `docs/reference/make-targets.md` |
| GitHub Actions | CI pipeline | `.github/workflows/yamllint.yml` |

### Security Documentation
- Token Management: `docs/reference/optional-configs-and-secrets.md`
- Authentication: `docs/reference/optional-configs-and-secrets.md`
- Private Registry Setup: `scripts/login-registry.sh`

## Agent Guidelines
When developing with this pattern:
1. Follow YAML conventions (2-space indent, no tabs)
2. Keep `execution-environment.yml` clean; add dependencies to `files/` instead
3. Update documentation when changing behavior
4. Follow PR guidelines with descriptive commit messages
5. Test with both local changes and CI validation before opening a PR
