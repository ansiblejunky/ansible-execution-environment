# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- ADR framework for architectural decisions ([ADR-0001](docs/adrs/0001-adopt-semantic-versioning.md), [ADR-0002](docs/adrs/0002-release-process.md))
- Automated changelog generation via ADR MCP tool ([ADR-0002](docs/adrs/0002-release-process.md))
- Dependabot for automated dependency updates ([ADR-0004](docs/adrs/0004-dependency-management.md))
- Retry logic for tarball downloads (3 attempts with delays) ([ADR-0005](docs/adrs/0005-oc-installation-strategy.md))
- Tarball integrity verification before extraction ([ADR-0005](docs/adrs/0005-oc-installation-strategy.md))
- Detailed logging for RHSM installation path ([ADR-0005](docs/adrs/0005-oc-installation-strategy.md))
- Enhanced curl flags for more reliable downloads ([ADR-0005](docs/adrs/0005-oc-installation-strategy.md))
- Troubleshooting documentation for intermittent download failures

### Changed
- OpenShift version updated from 4.19 to 4.21 ([ADR-0003](docs/adrs/0003-openshift-version-policy.md))
- RHSM path now tries 4.21, 4.20, 4.19 repos in sequence ([ADR-0003](docs/adrs/0003-openshift-version-policy.md))
- Tarball path uses stable-4.21 for improved reliability ([ADR-0003](docs/adrs/0003-openshift-version-policy.md))
- oc/kubectl installation error handling improved across both paths ([ADR-0005](docs/adrs/0005-oc-installation-strategy.md))

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
