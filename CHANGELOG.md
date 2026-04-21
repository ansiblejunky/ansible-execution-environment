# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-04-21

### Added
- ADR framework for architectural decisions (8 ADRs total)
  - [ADR-0001](docs/adrs/0001-adopt-semantic-versioning.md): Semantic Versioning
  - [ADR-0002](docs/adrs/0002-release-process.md): Release Process and Tooling
  - [ADR-0003](docs/adrs/0003-openshift-version-policy.md): OpenShift Version Policy
  - [ADR-0004](docs/adrs/0004-dependency-management.md): Dependency Management Strategy
  - [ADR-0005](docs/adrs/0005-oc-installation-strategy.md): oc/kubectl Installation Strategy
  - [ADR-0006](docs/adrs/0006-development-environment-setup.md): Development Environment Setup (Python 3.11+ requirement)
  - [ADR-0007](docs/adrs/0007-aap-collection-dependencies.md): AAP Collection Dependencies
  - [ADR-0008](docs/adrs/0008-collection-dependency-validation.md): Collection Dependency Validation
- Automated changelog generation via ADR MCP tool ([ADR-0002](docs/adrs/0002-release-process.md))
- Dependabot for automated dependency updates ([ADR-0004](docs/adrs/0004-dependency-management.md))
  - Weekly GitHub Actions updates
  - Monthly Python and container image updates
- Retry logic for tarball downloads (3 attempts with 5-second delays) ([ADR-0005](docs/adrs/0005-oc-installation-strategy.md))
- Tarball integrity verification before extraction ([ADR-0005](docs/adrs/0005-oc-installation-strategy.md))
- Detailed logging for RHSM installation path ([ADR-0005](docs/adrs/0005-oc-installation-strategy.md))
- Enhanced curl flags for more reliable downloads (`--fail --retry 3 --retry-delay 5 --max-time 300`) ([ADR-0005](docs/adrs/0005-oc-installation-strategy.md))
- Troubleshooting documentation for intermittent download failures
- Python 3.10+ requirement enforcement in Makefile ([ADR-0006](docs/adrs/0006-development-environment-setup.md))
- Automated virtual environment creation with `make setup` ([ADR-0006](docs/adrs/0006-development-environment-setup.md))
- Collection dependency validation script (`scripts/validate-collection-deps.sh`) ([ADR-0008](docs/adrs/0008-collection-dependency-validation.md))
  - Pre-build validation for OpenShift-dependent collections
  - Clear error messages with remediation steps
- Dummy `openshift-clients` RPM (0.0.1-1) to satisfy kubernetes.core bindep requirement ([ADR-0007](docs/adrs/0007-aap-collection-dependencies.md))
- Comprehensive functional test playbook (`files/playbook.yml`) with 36 tasks ([ADR-0007](docs/adrs/0007-aap-collection-dependencies.md))
  - Tests kubernetes.core (oc/kubectl binary access, module documentation)
  - Tests ansible.hub (module availability)
  - Tests ansible.controller (module availability)
  - Tests ansible.platform (dependency chain validation)
  - Tests amazon.aws, azure.azcollection, community.general, ansible.utils
- Enhanced test suite (`scripts/test-openshift-tooling.sh`) with 7 comprehensive tests
- Additional Ansible collections enabled and tested:
  - kubernetes.core 6.3.0 (with oc/kubectl 4.21.9 integration)
  - ansible.platform 2.6.20260306 (AAP infrastructure)
- Documentation for release process (`docs/how-to/release-process.md`)
- RELEASE_TASKS.md for tracking release phases and checklist
- requirements-dev.txt for development dependencies (ansible-builder, ansible-navigator, yamllint)
- .venv-activate.sh helper script for virtual environment activation

### Changed
- OpenShift version updated from 4.19 to 4.21.9 ([ADR-0003](docs/adrs/0003-openshift-version-policy.md))
  - oc Client Version: 4.21.9
  - kubectl Client Version: v1.34.1
- RHSM path now tries 4.21, 4.20, 4.19 repos in sequence ([ADR-0003](docs/adrs/0003-openshift-version-policy.md))
- Tarball path uses stable-4.21 for improved reliability ([ADR-0003](docs/adrs/0003-openshift-version-policy.md))
- oc/kubectl installation error handling improved across both paths ([ADR-0005](docs/adrs/0005-oc-installation-strategy.md))
- ansible-runner version constraint changed from ==2.4.1 to >=2.4.1 to fix base image conflicts
- Multi-stage build enhanced to copy oc/kubectl binaries from galaxy stage to final stage
- Makefile updated to enforce Python 3.10+ requirement with clear error messages
- Test scripts updated to bypass entrypoint for improved compatibility

### Fixed
- curl-minimal package conflict resolved with `rpm -e --nodeps curl-minimal` before curl installation
- ansible-runner version conflict (base image 2.4.2 vs specified 2.4.1)
- Multi-stage Dockerfile build not copying oc/kubectl binaries to final image
- Duplicate `prepend_galaxy` sections in execution-environment.yml causing build cache issues
- Entrypoint permission issues in test scripts
- Collection dependency validation integrated into build workflow

### Documented
- Path A (RHSM) limitation: Not viable for containerized builds (subscription-manager container mode) ([ADR-0007](docs/adrs/0007-aap-collection-dependencies.md))
- Path B (Tarball) confirmed as recommended approach for all environments ([ADR-0007](docs/adrs/0007-aap-collection-dependencies.md))
- AAP collection dependency chain: ansible.platform → kubernetes.core → oc/kubectl binaries ([ADR-0007](docs/adrs/0007-aap-collection-dependencies.md))
- Python 3.11/3.12 recommended, 3.10 minimum requirement ([ADR-0006](docs/adrs/0006-development-environment-setup.md))

### Testing
- ✅ All 7 functional tests passing (100% success rate)
- ✅ 36 Ansible tasks executed successfully (0 failures)
- ✅ 8 AAP collections verified working with actual module checks
- ✅ OpenShift 4.21.9 binaries installed and functional
- ✅ Binary permissions verified (755)
- ✅ Dependency chain validation passing

## [1.0.0] - 2026-04-20

### Added
- Initial baseline release with structured semantic versioning ([ADR-0001](docs/adrs/0001-adopt-semantic-versioning.md))
- OpenShift 4.19 support via two installation paths:
  - Path A: RHSM-based RPM installation
  - Path B: Tarball installation from mirror.openshift.com
- Ansible Automation Platform 2.5 base image (ee-minimal-rhel9)
- Makefile-driven build system with targets for build, test, publish
- GitHub Actions CI/CD pipeline:
  - Baseline testing
  - OpenShift RHSM testing
  - OpenShift tarball testing
  - Documentation build and deployment
  - YAML linting
- Comprehensive documentation:
  - Tutorials: Getting started guide
  - How-to guides: Building, testing, CI/CD, Kubernetes/OpenShift, troubleshooting
  - Reference: Makefile targets, YAML specification, optional configurations
  - Explanation: Concepts, design decisions, technology stack
- Ansible collections: ansible.hub, ansible.controller, amazon.aws, azure.azcollection, community.general, ansible.utils
- Python dependencies: ara (playbook recording), pip, setuptools
- System dependencies: dnf, git, jq, rsync, curl, tar, python3-pip

[Unreleased]: https://github.com/tosin2013/ansible-execution-environment/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/tosin2013/ansible-execution-environment/releases/tag/v1.0.0
