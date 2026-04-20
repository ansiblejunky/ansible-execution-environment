# ADR-0006: Development Environment Setup

**Status:** Accepted  
**Date:** 2026-04-20  
**Deciders:** Development Team  
**Tags:** development, python, environment, tooling, setup

## Context

The ansible-execution-environment project requires specific tools for building and testing:
- **ansible-builder**: Builds execution environment container images
- **ansible-navigator**: Tests execution environments and runs playbooks
- **ansible-core**: Core Ansible functionality
- **Python 3.10+**: Required by ansible-navigator (Python 3.9 is insufficient)

Current challenges:
1. RHEL 9 systems ship with Python 3.9 by default
2. ansible-navigator requires Python 3.10 or later
3. System-wide Python upgrades can break system tools
4. Multiple developers need consistent environments
5. CI/CD needs reproducible builds
6. Users may not have sudo access for system packages

The current `make setup` target detects issues but doesn't provide automated solutions for Python version conflicts.

## Decision

Adopt a **virtual environment (venv) based development setup** with support for Python 3.11+ and automated tool installation.

### Core Principles

1. **Never modify system Python**: Use venv to isolate development dependencies
2. **Support Python 3.11 and 3.12**: RHEL 9 provides these via appstream
3. **Automated setup**: `make setup` should create and activate venv
4. **Reproducible environments**: Pin tool versions in requirements-dev.txt
5. **CI/CD alignment**: Use same venv approach in GitHub Actions

### Implementation

#### 1. Virtual Environment Creation

```bash
# Detect Python 3.11, 3.12, or 3.10 (in order of preference)
PYTHON_BIN=$(command -v python3.11 || command -v python3.12 || command -v python3.10)

# Create venv if it doesn't exist
if [ ! -d .venv ]; then
    $PYTHON_BIN -m venv .venv
fi

# Activate venv
source .venv/bin/activate
```

#### 2. Development Dependencies

Create `requirements-dev.txt`:
```txt
# Ansible Automation Platform tools
ansible-builder>=3.0.0
ansible-navigator>=3.0.0
ansible-core>=2.15.0

# Development tools
yamllint>=1.26.0
ansible-lint>=6.0.0  # Optional linting
```

#### 3. Enhanced Setup Target

Update `make setup`:
- Detect available Python 3.10+ versions
- Create or activate venv
- Install tools via pip in venv
- Verify ANSIBLE_HUB_TOKEN
- Provide clear instructions if prerequisites missing

#### 4. Activation Helper

Create `.venv-activate.sh`:
```bash
#!/bin/bash
# Source this file to activate the development environment
# Usage: source .venv-activate.sh

if [ -d .venv ]; then
    source .venv/bin/activate
    echo "✓ Development environment activated"
    echo "  Python: $(python --version)"
    echo "  ansible-builder: $(ansible-builder --version 2>/dev/null || echo 'not found')"
    echo "  ansible-navigator: $(ansible-navigator --version 2>/dev/null || echo 'not found')"
else
    echo "ERROR: .venv not found. Run 'make setup' first."
    return 1
fi
```

#### 5. Updated .gitignore

Add venv directories:
```gitignore
# Virtual environments
.venv/
venv/
.venv-*/
```

### Makefile Integration

All build/test targets should activate venv first:
```makefile
# Ensure venv is activated for targets that need it
.PHONY: activate-venv
activate-venv:
	@if [ ! -d .venv ]; then \
		echo "ERROR: Virtual environment not found. Run 'make setup' first."; \
		exit 1; \
	fi

build: activate-venv
	@. .venv/bin/activate && ansible-builder build ...

test: activate-venv
	@. .venv/bin/activate && ansible-navigator run ...
```

## Consequences

### Positive

- **No system Python conflicts**: Venv isolates development tools
- **Consistent across environments**: Same Python version and tools everywhere
- **No sudo required**: Users can set up without system admin access
- **CI/CD reproducibility**: GitHub Actions can use same venv approach
- **Version pinning**: requirements-dev.txt locks tool versions
- **Easy cleanup**: `rm -rf .venv` to reset environment
- **Python 3.11+ support**: Newer Python features available
- **Better error messages**: Setup detects and guides installation

### Negative

- **Additional step**: Developers must activate venv (can be automated)
- **Disk space**: Each checkout has its own venv (~100MB)
- **Learning curve**: New users may not understand venv
- **Makefile complexity**: Targets need venv activation logic

### Neutral

- Python 3.9 still supported via system Python for users who have 3.10+ alternatives
- Venv needs periodic recreation if Python version changes
- Documentation needs update to explain venv workflow

## Alternatives Considered

### System-Wide Installation

Install ansible-builder/navigator system-wide via dnf or pip

**Pros:**
- Single installation for all projects
- No venv management needed

**Cons:**
- Requires sudo access
- Can conflict with other projects' versions
- System Python 3.9 insufficient for ansible-navigator
- Upgrading system Python risky

**Rejected because:** System-wide installation breaks in Python 3.9 environments and requires sudo.

### Conda/Mamba Environment

Use conda for environment management instead of venv

**Pros:**
- Handles both Python and system packages
- Popular in data science community

**Cons:**
- Large installation footprint
- Not standard Python tooling
- Adds external dependency
- Overkill for our use case

**Rejected because:** venv is Python standard library, lighter weight, and sufficient.

### Docker-Based Development

Run all development tools in a container

**Pros:**
- Complete isolation
- Includes all system dependencies

**Cons:**
- Nested containers (developing containers in containers)
- Complex IDE integration
- Slower filesystem operations
- More complex setup

**Rejected because:** Adds unnecessary complexity when venv solves the problem.

### Python Version Detection Only

Keep current approach: detect and warn about Python version

**Pros:**
- No changes needed
- Users choose their own solution

**Cons:**
- Doesn't solve the problem
- Users stuck without clear path forward
- Inconsistent environments

**Rejected because:** Doesn't provide automated solution, creates friction.

## Implementation Notes

### Phase 1: Core venv Support
1. Create requirements-dev.txt
2. Update make setup to create venv
3. Create .venv-activate.sh helper
4. Update .gitignore

### Phase 2: Makefile Integration
5. Add activate-venv target
6. Update build, test, lint targets to use venv
7. Update CI/CD workflows to use venv

### Phase 3: Documentation
8. Update docs/tutorials/getting-started.md
9. Update README.md with venv instructions
10. Add troubleshooting for venv issues

### Installation of Python 3.11 on RHEL 9

For users without Python 3.11/3.12:
```bash
# Install Python 3.11 from appstream
sudo dnf install -y python3.11 python3.11-pip python3.11-devel

# Verify
python3.11 --version  # Should show 3.11.x
```

### Testing

Verify venv setup works:
```bash
# Clean start
rm -rf .venv

# Run setup
make setup

# Activate venv
source .venv/bin/activate

# Verify tools
ansible-builder --version
ansible-navigator --version
python --version  # Should show 3.11+ or 3.10+

# Test build
make build
```

## Migration Path

### For Existing Users

Users with system-wide ansible-builder/navigator:
1. Continue using system installation (still supported)
2. Optional: Switch to venv for isolation
3. `make setup` creates venv but doesn't force it

### For New Users

1. Run `make setup` (creates venv automatically)
2. Source `.venv-activate.sh` or `source .venv/bin/activate`
3. Run `make build` (automatically uses venv)

### For CI/CD

Update GitHub Actions workflows:
```yaml
- name: Set up development environment
  run: |
    python3.11 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements-dev.txt

- name: Build
  run: |
    source .venv/bin/activate
    make build
```

## Success Criteria

- [ ] `make setup` creates functional venv on RHEL 9
- [ ] Python 3.11 and 3.12 both work
- [ ] `make build` and `make test` work in venv
- [ ] CI/CD uses venv approach
- [ ] Documentation updated
- [ ] Users can develop without sudo access
- [ ] No Python version conflicts

## References

- [Python venv Documentation](https://docs.python.org/3/library/venv.html)
- [RHEL 9 Python 3.11 Installation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/installing_and_using_dynamic_programming_languages/assembly_installing-and-using-python_installing-and-using-dynamic-programming-languages)
- [ansible-navigator Requirements](https://ansible.readthedocs.io/projects/navigator/installation/)
- [ADR-0001: Semantic Versioning](0001-adopt-semantic-versioning.md)
