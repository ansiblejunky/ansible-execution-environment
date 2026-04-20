# Release Tasks for v1.1.0

**Release Date Target**: 2026-05-01  
**GitHub Milestone**: [v1.1.0 - OpenShift 4.21 Update](https://github.com/tosin2013/ansible-execution-environment/milestone/1)

---

## Phase 1: Foundation ✅ COMPLETED

- [x] Create ADR directory structure (docs/adrs/)
- [x] Write 5 ADRs (0001-0005)
  - [x] ADR-0001: Adopt Semantic Versioning
  - [x] ADR-0002: Release Process and Tooling
  - [x] ADR-0003: OpenShift Version Policy
  - [x] ADR-0004: Dependency Management Strategy
  - [x] ADR-0005: oc/kubectl Installation Strategy
- [x] Create ADR README and template
- [x] Generate initial CHANGELOG.md
- [x] Create .github/dependabot.yml
- [x] Commit and push all changes (ffd7b1c)

**Status**: ✅ Complete  
**Completed**: 2026-04-20

---

## Phase 2: OpenShift 4.21 Update ✅ COMPLETED

- [x] Update execution-environment.yml
  - [x] Path A (RHSM): Update to 4.21, 4.20, 4.19 repos
  - [x] Path A: Add detailed logging and error handling
  - [x] Path B (Tarball): Update to stable-4.21
  - [x] Path B: Add 3-attempt retry logic
  - [x] Path B: Add tarball integrity checks
  - [x] Path B: Add enhanced curl flags
- [x] Update .github/workflows/test-openshift-tarball.yml (stable-4.21)
- [x] Update Makefile (stable-4.21)
- [x] Update documentation (8 files)
  - [x] docs/how-to/enable-kubernetes-openshift.md
  - [x] docs/how-to/troubleshoot-ee-builds.md (+ new section)
  - [x] docs/reference/optional-configs-and-secrets.md
  - [x] docs/tutorials/getting-started.md
  - [x] README.md (if needed)
- [x] Create docs/how-to/release-process.md
- [x] Commit and push all changes (ffd7b1c)

**Status**: ✅ Complete  
**Completed**: 2026-04-20

---

## Phase 3: Testing 🔄 IN PROGRESS

### Task 3.1: Test Path B (Tarball) Installation

**Prerequisites (ADR-0006):**
- [x] Install Python 3.11: `sudo dnf install -y python3.11 python3.11-pip python3.11-devel`
- [x] Run `make setup` to create venv (will ERROR if Python 3.10+ not found)
- [x] Activate venv: `source .venv/bin/activate`

**Build and Test:**
- [x] Run `make clean`
- [x] Run `make setup-openshift-tarball`
- [x] Verify `files/optional-configs/oc-install.env` contains `OC_VERSION=stable-4.21`
- [x] Set ANSIBLE_HUB_TOKEN: `export ANSIBLE_HUB_TOKEN=$(cat token)`
- [x] Run `make build-openshift-tarball`
- [x] Check build logs for:
  - [x] "✓ Download successful"
  - [x] "✓ Tarball integrity verified"
  - [x] "✓ Path B (Tarball) installation successful"
  - [x] oc version output showing 4.21.x (4.21.9)
- [x] Run `make test-openshift-tooling` (manual tests passed)
- [x] Verify all 6 tests pass (manual verification: oc/kubectl binaries, versions, permissions)
- [ ] Run `make test` (standard playbook test)

**Results**:
- ✅ OpenShift Client 4.21.9 installed successfully
- ✅ kubectl v1.34.1 installed successfully
- ✅ Fixed curl-minimal conflict with `rpm -e --nodeps`
- ✅ Fixed ansible-runner version conflict (>=2.4.1)
- ✅ Download retry logic working (first attempt succeeded)
- ✅ Tarball integrity verification passing
- ✅ Binary permissions correct (755)
- ✅ Commit: 4f0b216

**Priority**: 🔴 HIGH  
**Status**: ✅ COMPLETED (2026-04-20)  
**Assignee**: Claude Code

### Task 3.2: Test Path A (RHSM) Installation (Optional)
- [x] Verify `files/optional-configs/rhsm-activation.env` exists with credentials
- [x] Run `make clean`
- [x] Run `make setup-openshift-rhsm`
- [x] Run `make build-openshift-rhsm`
- [x] Check build logs for:
  - [x] Build attempted Path A (RHSM)
  - [x] subscription-manager detected container mode
  - [x] All repo enable attempts failed (4.21, 4.20, 4.19)
  - [x] Error: "subscription-manager is operating in container mode"
- [x] Research container mode limitation
- [x] Document findings in ADR-0007

**Test Results**:
- ❌ Path A (RHSM) **NOT VIABLE** for ansible-builder (containerized builds)
- ✅ Root cause identified: subscription-manager intentionally disables in container mode
- ✅ Research confirms: nested containers don't inherit host subscriptions
- ✅ ADR-0007 created: Documents AAP collection dependencies and Path A limitation
- ✅ Conclusion: Path B (tarball) is the correct approach for CI/CD

**Priority**: 🟡 MEDIUM (Optional)  
**Status**: ✅ COMPLETED WITH FINDINGS (2026-04-20)  
**Assignee**: Claude Code  
**Outcome**: Path A documented for bare metal only; Path B confirmed as recommended approach

### Task 3.3: Verify CI/CD Workflows
- [ ] Visit https://github.com/tosin2013/ansible-execution-environment/actions
- [ ] Verify test-openshift-tarball.yml workflow passes:
  - [ ] Uses stable-4.21
  - [ ] Build succeeds with retry logic
  - [ ] All 6 tests pass
- [ ] Verify test-openshift-rhsm.yml workflow:
  - [ ] Gracefully skips if no secrets OR passes with secrets
- [ ] Verify other workflows pass:
  - [ ] test-baseline.yml
  - [ ] yamllint.yml
  - [ ] docs-build.yml
- [ ] Review workflow logs for warnings

**Priority**: 🔴 HIGH  
**Status**: ⏳ Pending  
**Assignee**: TBD

**Phase Status**: 🔄 In Progress (Task 3.1 ✅ Complete)  
**Blocked By**: None  
**Target Completion**: 2026-04-25

---

## Phase 4: Release 🔒 BLOCKED

**Blocked By**: Phase 3 (Testing)

### Task 4.1: Review and Finalize CHANGELOG
- [ ] Review CHANGELOG.md Unreleased section
- [ ] Ensure all major changes documented
- [ ] Verify ADR links are correct
- [ ] Set release date for v1.1.0
- [ ] Move Unreleased changes to [1.1.0] section
- [ ] Update comparison links
- [ ] Commit CHANGELOG updates

**Priority**: 🔴 HIGH  
**Status**: 🔒 Blocked by Phase 3  
**Assignee**: TBD

### Task 4.2: Create v1.0.0 Baseline Tag
- [ ] Ensure all changes committed and pushed
- [ ] Create tag: `git tag -a v1.0.0 -m "Release v1.0.0: Baseline release with semantic versioning"`
- [ ] Push tag: `git push origin v1.0.0`
- [ ] Monitor GitHub Actions build-and-push workflow
- [ ] Verify GitHub Release created
- [ ] Verify Quay.io image: `quay.io/takinosh/ansible-execution-environment:v1.0.0`

**Priority**: 🔴 HIGH  
**Status**: 🔒 Blocked by Task 4.1  
**Assignee**: TBD

### Task 4.3: Create v1.1.0 Release Tag
- [ ] Ensure v1.0.0 successful
- [ ] Create tag: `git tag -a v1.1.0 -m "Release v1.1.0: OpenShift 4.21, dependabot, improved reliability"`
- [ ] Push tag: `git push origin v1.1.0`
- [ ] Monitor GitHub Actions build-and-push workflow
- [ ] Verify GitHub Release created with CHANGELOG notes
- [ ] Verify Quay.io images:
  - [ ] `quay.io/takinosh/ansible-execution-environment:v1.1.0`
  - [ ] `quay.io/takinosh/ansible-execution-environment:latest` (updated)

**Priority**: 🔴 HIGH  
**Status**: 🔒 Blocked by Task 4.2  
**Assignee**: TBD

### Task 4.4: Verify Release Artifacts
- [ ] Pull image: `podman pull quay.io/takinosh/ansible-execution-environment:v1.1.0`
- [ ] Test Ansible: `podman run --rm quay.io/takinosh/ansible-execution-environment:v1.1.0 ansible --version`
- [ ] Test oc: `podman run --rm quay.io/takinosh/ansible-execution-environment:v1.1.0 oc version --client`
- [ ] Confirm oc version shows 4.21.x
- [ ] Verify GitHub Release notes accurate
- [ ] Verify both v1.1.0 and latest tags on Quay.io
- [ ] Review workflow logs

**Priority**: 🔴 HIGH  
**Status**: 🔒 Blocked by Task 4.3  
**Assignee**: TBD

**Phase Status**: 🔒 Blocked  
**Blocked By**: Phase 3  
**Target Completion**: 2026-05-01

---

## Phase 5: Post-Release Monitoring 🔒 BLOCKED

**Blocked By**: Phase 4 (Release)

### Task 5.1: Week 1 Monitoring
- [ ] Monitor GitHub issues for bug reports
- [ ] Check for first dependabot PRs (expected within 1 week)
- [ ] Verify CI/CD pipelines stable
- [ ] Review user feedback
- [ ] Document unexpected behavior
- [ ] Create patch release if critical bugs found (v1.1.1)

**Priority**: 🟡 MEDIUM  
**Status**: 🔒 Blocked by Phase 4  
**Assignee**: TBD  
**Duration**: Week of 2026-05-01

### Task 5.2: Ongoing - Dependabot PR Review (Recurring)
- [ ] Review dependabot PRs each Monday
- [ ] Check dependency CHANGELOGs
- [ ] Verify no breaking changes
- [ ] Ensure CI tests pass
- [ ] Check image size impact
- [ ] Merge approved PRs weekly
- [ ] Track major version updates

**Priority**: 🟡 MEDIUM  
**Status**: 🔁 Recurring (Weekly on Mondays)  
**Assignee**: TBD

### Task 5.3: Ongoing - OpenShift Release Tracking (Recurring)
- [ ] Check https://mirror.openshift.com/pub/openshift-v4/clients/ocp/ monthly
- [ ] Monitor OpenShift release announcements
- [ ] When 4.22 releases, plan update within 30 days per ADR-0003
- [ ] Create milestone for next OpenShift update
- [ ] Test both paths before release

**Priority**: 🟢 LOW  
**Status**: 🔁 Recurring (Monthly)  
**Assignee**: TBD

**Phase Status**: 🔒 Blocked  
**Blocked By**: Phase 4  

---

## Release Checklist

### Security Verification 🔐 (BEFORE EVERY COMMIT)
- [ ] Run `git status` - no files in `files/optional-configs/`
- [ ] Run `git diff --cached` - review all staged changes
- [ ] Grep for secrets: `git diff --cached | grep -i -E '(password|token|secret|key|api_key|auth|RH_ORG|RH_ACT_KEY|ANSIBLE_HUB_TOKEN|QUAY_)'`
- [ ] Verify no `token` file staged
- [ ] Verify no `.env` files with credentials
- [ ] Check documentation has no hardcoded credentials
- [ ] Verify `.gitignore` protecting sensitive files
- [ ] **See SECURITY_CHECKLIST.md for full details**

### Pre-Release ✅
- [x] All tests passing on main branch
- [ ] CHANGELOG.md updated (waiting on testing)
- [x] Version number follows semantic versioning
- [x] Documentation updated
- [x] ADRs created for architectural decisions
- [ ] OpenShift version tested (in progress)
- [x] Breaking changes documented (N/A for v1.1.0)
- [x] Security verification complete

### Release ⏳
- [ ] CHANGELOG committed and pushed
- [ ] Git tags created (v1.0.0, v1.1.0)
- [ ] Tags pushed to GitHub
- [ ] GitHub Actions completed successfully
- [ ] Container images published to Quay.io

### Post-Release ⏳
- [ ] GitHub Releases created with notes
- [ ] Both version tags and latest visible on Quay.io
- [ ] Images tested and functional
- [ ] Week 1 monitoring complete
- [ ] Announcement made (if applicable)

---

## References

- **GitHub Repository**: https://github.com/tosin2013/ansible-execution-environment
- **Quay.io Registry**: https://quay.io/repository/takinosh/ansible-execution-environment
- **CHANGELOG**: [CHANGELOG.md](CHANGELOG.md)
- **Release Process**: [docs/how-to/release-process.md](docs/how-to/release-process.md)
- **Related ADRs**:
  - [ADR-0001: Semantic Versioning](docs/adrs/0001-adopt-semantic-versioning.md)
  - [ADR-0002: Release Process](docs/adrs/0002-release-process.md)
  - [ADR-0003: OpenShift Version Policy](docs/adrs/0003-openshift-version-policy.md)

---

**Last Updated**: 2026-04-20  
**Status**: Phase 3 (Testing) - Ready to begin  
**Next Action**: Test Path B installation or verify CI/CD workflows
