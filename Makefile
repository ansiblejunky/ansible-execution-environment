# Ansible Automation Platform - Makefile for Execution Environments
# Original version found on ansiblejunky @ https://github.com/ansiblejunky/ansible-execution-environment
#
# Output Visibility:
#   - All build output is displayed in real-time using 'tee' commands
#   - Output is both shown on stdout and saved to log files
#   - To see even more verbose output, set VERBOSITY=3 (default) or higher
#   - Run with 'make -n build' to see what commands would be executed without running them

# Update defaults
TARGET_TAG ?= v5
CONTAINER_ENGINE ?= podman
VERBOSITY ?= 3
SOURCE_HUB ?= registry.redhat.io
SOURCE_TOKEN ?= ANSIBLE_HUB_TOKEN
#SOURCE_USERNAME ?= jwadleig
TARGET_HUB ?= quay.io
#TARGET_USERNAME ?= jwadleig
TARGET_NAME ?= ansible-ee-minimal

# Check ANSIBLE_HUB_TOKEN only for targets that need it
# Use .PHONY target with a check that runs at execution time, not parse time
.PHONY: check-token
check-token:
	@if [ -z "$$ANSIBLE_HUB_TOKEN" ]; then \
		echo "ERROR: The environment variable ANSIBLE_HUB_TOKEN is undefined and required for this target"; \
		exit 1; \
	fi

.PHONY : header clean lint check build scan test publish list shell docs-setup docs-build docs-serve docs-test token setup
.PHONY : build-openshift-tarball build-openshift-rhsm test-openshift-tooling setup-openshift-tarball setup-openshift-rhsm
all: header clean lint build test publish

header:
	@echo "\n\n***************************** Ansible Automation Platform - Makefile for Execution Environments \n"

clean: # Clean temporary files, folders and images
	@echo "\n\n***************************** Cleaning... \n"
	rm -rf \
		context \
		ansible-navigator.log \
		ansible-builder.log \
		ansible-builder.bak.log \
		collections
	$(CONTAINER_ENGINE) image prune -a -f

setup: # Setup development environment with required tools and dependencies
	@echo "\n\n***************************** Setting up Development Environment... \n"
	@echo "Detecting system environment..."
	@if [ -f /etc/os-release ]; then \
		. /etc/os-release; \
		echo "✓ OS: $$ID $$VERSION_ID"; \
		RHEL_VERSION=$$(echo $$VERSION_ID | cut -d. -f1); \
	else \
		echo "WARNING: Could not detect OS version"; \
		RHEL_VERSION=""; \
	fi
	@echo "Checking for required system packages..."
	@MISSING=; \
	command -v podman >/dev/null 2>&1 || MISSING="$$MISSING podman"; \
	command -v python3 >/dev/null 2>&1 || MISSING="$$MISSING python3 python3-pip"; \
	command -v git >/dev/null 2>&1 || MISSING="$$MISSING git"; \
	command -v jq >/dev/null 2>&1 || MISSING="$$MISSING jq"; \
	command -v envsubst >/dev/null 2>&1 || MISSING="$$MISSING gettext"; \
	if [ -n "$$MISSING" ]; then \
		echo "ERROR: Missing required system packages:$$MISSING"; \
		echo "Install them with: sudo dnf install -y$$MISSING"; \
		exit 1; \
	else \
		echo "✓ All required system packages are installed"; \
	fi
	@command -v skopeo >/dev/null 2>&1 || echo "WARNING: skopeo is not installed (optional). Install with: sudo dnf install -y skopeo"
	@command -v yamllint >/dev/null 2>&1 || echo "WARNING: yamllint is not installed. Install with: sudo dnf install -y yamllint (or: pip3 install yamllint)"
	@echo "Checking Python version..."
	@PYTHON3_CMD="python3"; \
	PYTHON_VERSION=$$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown"); \
	if [ "$$PYTHON_VERSION" != "unknown" ]; then \
		PY_MAJOR=$$(echo $$PYTHON_VERSION | cut -d. -f1); \
		PY_MINOR=$$(echo $$PYTHON_VERSION | cut -d. -f2); \
		if [ $$PY_MAJOR -gt 3 ] || ([ $$PY_MAJOR -eq 3 ] && [ $$PY_MINOR -ge 10 ]); then \
			echo "✓ Python $$PYTHON_VERSION (meets requirement: 3.10+)"; \
		else \
			echo "WARNING: Python $$PYTHON_VERSION detected. ansible-navigator requires Python 3.10 or later."; \
			echo "Checking for Python 3.10+ alternatives..."; \
			if command -v python3.11 >/dev/null 2>&1; then \
				PY311_VER=$$(python3.11 --version 2>&1 | awk '{print $$2}'); \
				echo "✓ Found python3.11 ($$PY311_VER) - can be used instead"; \
				PYTHON3_CMD="python3.11"; \
			elif command -v python3.10 >/dev/null 2>&1; then \
				PY310_VER=$$(python3.10 --version 2>&1 | awk '{print $$2}'); \
				echo "✓ Found python3.10 ($$PY310_VER) - can be used instead"; \
				PYTHON3_CMD="python3.10"; \
			elif command -v python3.12 >/dev/null 2>&1; then \
				PY312_VER=$$(python3.12 --version 2>&1 | awk '{print $$2}'); \
				echo "✓ Found python3.12 ($$PY312_VER) - can be used instead"; \
				PYTHON3_CMD="python3.12"; \
			else \
				echo "Python 3.10+ not found. Install with:"; \
				echo "  sudo dnf install -y python3.11 python3.11-pip"; \
				echo "  (or python3.10/python3.12 if available)"; \
			fi; \
		fi; \
	else \
		echo "WARNING: Could not determine Python version"; \
	fi
	@echo "Setting up virtual environment (ADR-0006)..."
	@echo "Detecting Python 3.10+ (required for ansible-navigator)..."
	@PYTHON_CMD=""; \
	if command -v python3.11 >/dev/null 2>&1; then \
		PYTHON_CMD="python3.11"; \
		echo "✓ Found python3.11 - will use for venv"; \
	elif command -v python3.12 >/dev/null 2>&1; then \
		PYTHON_CMD="python3.12"; \
		echo "✓ Found python3.12 - will use for venv"; \
	elif command -v python3.10 >/dev/null 2>&1; then \
		PYTHON_CMD="python3.10"; \
		echo "✓ Found python3.10 - will use for venv"; \
	else \
		echo ""; \
		echo "ERROR: Python 3.10 or later is REQUIRED (ADR-0006)"; \
		echo ""; \
		echo "ansible-navigator requires Python 3.10+, but only found:"; \
		python3 --version 2>/dev/null || echo "  No python3 found"; \
		echo ""; \
		echo "Install Python 3.11 (recommended):"; \
		echo "  sudo dnf install -y python3.11 python3.11-pip python3.11-devel"; \
		echo ""; \
		echo "Then run 'make setup' again."; \
		echo ""; \
		exit 1; \
	fi; \
	if [ ! -d .venv ]; then \
		echo "Creating virtual environment with $$PYTHON_CMD..."; \
		$$PYTHON_CMD -m venv .venv || { \
			echo "ERROR: Failed to create virtual environment"; \
			echo "Ensure $$PYTHON_CMD and venv module are installed"; \
			echo "Install with: sudo dnf install -y $${PYTHON_CMD} $${PYTHON_CMD}-pip"; \
			exit 1; \
		}; \
		echo "✓ Virtual environment created at .venv/"; \
	else \
		echo "✓ Virtual environment already exists at .venv/"; \
	fi; \
	if [ -f .venv/bin/activate ]; then \
		echo "Installing development tools in venv..."; \
		.venv/bin/pip install --upgrade pip > /dev/null 2>&1; \
		.venv/bin/pip install -r requirements-dev.txt || { \
			echo "WARNING: Failed to install some requirements from requirements-dev.txt"; \
			echo "You may need to install them manually:"; \
			echo "  source .venv/bin/activate"; \
			echo "  pip install -r requirements-dev.txt"; \
		}; \
		echo "✓ Development tools installed"; \
		echo ""; \
		echo "To activate the virtual environment:"; \
		echo "  source .venv/bin/activate"; \
		echo "  (or: source .venv-activate.sh for detailed info)"; \
		echo ""; \
	fi
	@echo "Checking for Ansible Automation Platform tools..."
	@PYTHON_CMD="python3"; \
	if command -v python3.11 >/dev/null 2>&1; then \
		PY311_VER=$$(python3.11 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo ""); \
		if [ -n "$$PY311_VER" ]; then \
			PY_MAJOR=$$(echo $$PY311_VER | cut -d. -f1); \
			PY_MINOR=$$(echo $$PY311_VER | cut -d. -f2); \
			if [ $$PY_MAJOR -gt 3 ] || ([ $$PY_MAJOR -eq 3 ] && [ $$PY_MINOR -ge 10 ]); then \
				PYTHON_CMD="python3.11"; \
			fi; \
		fi; \
	elif command -v python3.10 >/dev/null 2>&1; then \
		PY310_VER=$$(python3.10 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo ""); \
		if [ -n "$$PY310_VER" ]; then \
			PY_MAJOR=$$(echo $$PY310_VER | cut -d. -f1); \
			PY_MINOR=$$(echo $$PY310_VER | cut -d. -f2); \
			if [ $$PY_MAJOR -gt 3 ] || ([ $$PY_MAJOR -eq 3 ] && [ $$PY_MINOR -ge 10 ]); then \
				PYTHON_CMD="python3.10"; \
			fi; \
		fi; \
	elif command -v python3.12 >/dev/null 2>&1; then \
		PY312_VER=$$(python3.12 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo ""); \
		if [ -n "$$PY312_VER" ]; then \
			PY_MAJOR=$$(echo $$PY312_VER | cut -d. -f1); \
			PY_MINOR=$$(echo $$PY312_VER | cut -d. -f2); \
			if [ $$PY_MAJOR -gt 3 ] || ([ $$PY_MAJOR -eq 3 ] && [ $$PY_MINOR -ge 10 ]); then \
				PYTHON_CMD="python3.12"; \
			fi; \
		fi; \
	fi; \
	MISSING_NAV=; \
	MISSING_BUILDER=; \
	$$PYTHON_CMD -c "import ansible_navigator" >/dev/null 2>&1 || MISSING_NAV=1; \
	$$PYTHON_CMD -c "import ansible_builder" >/dev/null 2>&1 || MISSING_BUILDER=1; \
	if [ -n "$$MISSING_NAV" ] || [ -n "$$MISSING_BUILDER" ]; then \
		echo "Missing tools detected:"; \
		if [ -n "$$MISSING_NAV" ]; then \
			echo "  - ansible-navigator"; \
		fi; \
		if [ -n "$$MISSING_BUILDER" ]; then \
			echo "  - ansible-builder"; \
		fi; \
		echo ""; \
		if [ -f /etc/os-release ] && command -v subscription-manager >/dev/null 2>&1; then \
			. /etc/os-release; \
			RHEL_VER=$$(echo $$VERSION_ID | cut -d. -f1); \
			ARCH=$$(uname -m); \
			if [ "$$ID" = "rhel" ] && [ -n "$$RHEL_VER" ]; then \
				echo "RHEL system detected. Installing via RPM (recommended):"; \
				echo "  1. Attach Red Hat Ansible Automation Platform SKU:"; \
				echo "     subscription-manager attach --pool=<sku-pool-id>"; \
				echo ""; \
				if [ "$$RHEL_VER" = "8" ]; then \
					echo "  2. Install ansible-navigator:"; \
					echo "     sudo dnf install --enablerepo=ansible-automation-platform-2.4-for-rhel-8-$${ARCH}-rpms ansible-navigator"; \
				elif [ "$$RHEL_VER" = "9" ]; then \
					echo "  2. Install ansible-navigator:"; \
					echo "     sudo dnf install --enablerepo=ansible-automation-platform-2.4-for-rhel-9-$${ARCH}-rpms ansible-navigator"; \
				fi; \
				echo ""; \
				echo "  Note: ansible-builder may need to be installed via pip:"; \
				if [ "$$PYTHON_CMD" != "python3" ]; then \
					echo "     $$PYTHON_CMD -m pip install --user ansible-builder"; \
				else \
					echo "     pip3 install --user ansible-builder"; \
				fi; \
				echo ""; \
				echo "  Reference: https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.4/html/automation_content_navigator_creator_guide/assembly-installing_on_rhel_ansible-navigator"; \
			else \
				echo "Alternative: Install via pip:"; \
				if [ -n "$$MISSING_NAV" ]; then \
					if [ "$$PYTHON_CMD" != "python3" ]; then \
						echo "  $$PYTHON_CMD -m pip install --user 'ansible-navigator[ansible-core]'"; \
					else \
						echo "  pip3 install --user 'ansible-navigator[ansible-core]'"; \
					fi; \
				fi; \
				if [ -n "$$MISSING_BUILDER" ]; then \
					if [ "$$PYTHON_CMD" != "python3" ]; then \
						echo "  $$PYTHON_CMD -m pip install --user ansible-builder"; \
					else \
						echo "  pip3 install --user ansible-builder"; \
					fi; \
				fi; \
			fi; \
		else \
			echo "Install via pip:"; \
			if [ -n "$$MISSING_NAV" ]; then \
				if [ "$$PYTHON_CMD" != "python3" ]; then \
					echo "  $$PYTHON_CMD -m pip install --user 'ansible-navigator[ansible-core]'"; \
				else \
					echo "  pip3 install --user 'ansible-navigator[ansible-core]'"; \
				fi; \
			fi; \
			if [ -n "$$MISSING_BUILDER" ]; then \
				if [ "$$PYTHON_CMD" != "python3" ]; then \
					echo "  $$PYTHON_CMD -m pip install --user ansible-builder"; \
				else \
					echo "  pip3 install --user ansible-builder"; \
				fi; \
			fi; \
			echo ""; \
			echo "Or use the provision script: bash files/provision.sh"; \
		fi; \
	else \
		echo "✓ All required Ansible Automation Platform tools are installed (using $$PYTHON_CMD)"; \
	fi
	@PYTHON_CMD="python3"; \
	if command -v python3.11 >/dev/null 2>&1; then PYTHON_CMD="python3.11"; \
	elif command -v python3.10 >/dev/null 2>&1; then PYTHON_CMD="python3.10"; \
	elif command -v python3.12 >/dev/null 2>&1; then PYTHON_CMD="python3.12"; \
	fi; \
	$$PYTHON_CMD -c "import ansible" >/dev/null 2>&1 || echo "WARNING: ansible-core not found. Install with: $$PYTHON_CMD -m pip install --user ansible-core"
	@echo "Verifying tools are accessible..."
	@podman --version >/dev/null 2>&1 && echo "✓ podman: $$(podman --version)" || { echo "ERROR: podman is installed but not working"; exit 1; }
	@if command -v ansible-builder >/dev/null 2>&1; then \
		AB_VERSION=$$(ansible-builder --version 2>/dev/null | head -1); \
		echo "✓ ansible-builder: $$AB_VERSION"; \
	else \
		echo "WARNING: ansible-builder not found in PATH"; \
	fi
	@if command -v ansible-navigator >/dev/null 2>&1; then \
		AN_VERSION=$$(ansible-navigator --version 2>/dev/null | head -1); \
		echo "✓ ansible-navigator: $$AN_VERSION"; \
	else \
		echo "WARNING: ansible-navigator not found in PATH"; \
	fi
	@if [ -z "$$ANSIBLE_HUB_TOKEN" ]; then \
		echo "WARNING: ANSIBLE_HUB_TOKEN is not set. This is required for certified collections from Red Hat Automation Hub."; \
		echo "Set it with: export ANSIBLE_HUB_TOKEN=<your_token>"; \
	else \
		echo "✓ ANSIBLE_HUB_TOKEN is set (for certified collections)"; \
	fi
	@echo "\nDevelopment environment setup complete!"
	@echo "Next steps: make lint build test"

lint: # Lint the repository with yamllint
	@echo "\n\n***************************** Linting... \n"
	yamllint .

token: check-token # Test token
	@echo "\n\n***************************** Token... \n"
	envsubst < files/ansible.cfg.template > ./ansible.cfg
	mkdir -p collections
	ansible-galaxy collection download -r files/requirements.yml -p collections/

.PHONY: venv-check
venv-check: # Check if venv should be activated (ADR-0006)
	@if [ ! -d .venv ]; then \
		echo "INFO: No virtual environment found. Run 'make setup' to create one."; \
	elif [ -z "$$VIRTUAL_ENV" ]; then \
		if ! command -v ansible-builder >/dev/null 2>&1; then \
			echo "WARNING: ansible-builder not found in PATH."; \
			echo "Activate the virtual environment first:"; \
			echo "  source .venv/bin/activate"; \
			echo "  (or: source .venv-activate.sh)"; \
			echo ""; \
		fi; \
	fi

build: check-token venv-check # Build the execution environment image
	@echo "\n\n***************************** Building... \n"
	@if [ -n "$$REDHAT_REGISTRY_USERNAME" ] && [ -n "$$REDHAT_REGISTRY_PASSWORD" ]; then \
		echo "Logging in to $(SOURCE_HUB)..."; \
		echo "$$REDHAT_REGISTRY_PASSWORD" | $(CONTAINER_ENGINE) login $(SOURCE_HUB) \
			--username "$$REDHAT_REGISTRY_USERNAME" --password-stdin || true; \
	elif [ -f scripts/login-registry.sh ]; then \
		./scripts/login-registry.sh $(CONTAINER_ENGINE) || true; \
	else \
		echo "Warning: No registry credentials provided. Attempting login (may prompt for credentials)..."; \
		$(CONTAINER_ENGINE) login $(SOURCE_HUB) || echo "Warning: Login failed or skipped"; \
	fi
	@if [ -a ansible.cfg ] ; \
	then \
		echo "Using existing ansible.cfg"; \
	else \
		envsubst < files/ansible.cfg.template > ./ansible.cfg; \
	fi;
	if [ -a ansible-builder.log ] ; \
	then \
		cp ansible-builder.log ansible-builder.bak.log ; \
	fi;
	@echo "Running ansible-builder introspect (output will be shown below and saved to ansible-builder.log)..."
	ansible-builder introspect --sanitize --user-pip=files/requirements.txt --user-bindep=files/bindep.txt 2>&1 | tee ansible-builder.log
	@echo "Running ansible-builder build (output will be shown below and saved to ansible-builder.log)..."
	ansible-builder build \
			--tag $(TARGET_NAME):$(TARGET_TAG) \
			--verbosity $(VERBOSITY) \
			--container-runtime $(CONTAINER_ENGINE) 2>&1 | tee -a ansible-builder.log

scan: # Scan image for vulnerabilities https://www.redhat.com/sysadmin/using-quayio-scanner
	@echo "\n\n***************************** Scanning... \n"
	echo "TODO:"

inspect: # Inspect built image to show information
	@echo "\n\n***************************** Inspecting... \n"
	$(CONTAINER_ENGINE) inspect $(TARGET_NAME):$(TARGET_TAG)

list: # List the built image by name:tag
	@echo "\n\n***************************** Images... \n"
	$(CONTAINER_ENGINE) images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" --filter reference=$(TARGET_NAME):$(TARGET_TAG)

test: # Run the example playbook using the built container image
	@echo "\n\n***************************** Testing... \n"
	ansible-navigator run \
		files/playbook.yml \
		--container-engine $(CONTAINER_ENGINE) \
		--mode stdout \
		--pull-policy never \
		--execution-environment-image $(TARGET_NAME):$(TARGET_TAG)

info: # Produce information about the published container image that can be used as the README in AAP
	@echo "\n\n***************************** Image Layers ... \n"
	$(CONTAINER_ENGINE) history --human $(TARGET_NAME):$(TARGET_TAG)
	@echo "\n\n***************************** Ansible Version ... \n"
	$(CONTAINER_ENGINE) container run -it --rm $(TARGET_NAME):$(TARGET_TAG) ansible --version
	@echo "\n\n***************************** Ansible Collections ... \n"
	$(CONTAINER_ENGINE) container run -it --rm $(TARGET_NAME):$(TARGET_TAG) ansible-galaxy collection list
	@echo "\n\n***************************** Python Modules ... \n"
	$(CONTAINER_ENGINE) container run -it --rm $(TARGET_NAME):$(TARGET_TAG) pip3 list --format freeze
	@echo "\n\n***************************** System Packages ... \n"
	$(CONTAINER_ENGINE) container run -it --rm $(TARGET_NAME):$(TARGET_TAG) rpm -qa

publish: # Publish the image with proper tags to container registry
	@echo "\n\n***************************** Publishing... \n"
	$(CONTAINER_ENGINE) login $(TARGET_HUB)
	$(CONTAINER_ENGINE) tag  \
		$(TARGET_NAME):$(TARGET_TAG) $(TARGET_NAME):latest
	$(CONTAINER_ENGINE) tag  \
		$(TARGET_NAME):$(TARGET_TAG) \
		$(TARGET_HUB)/$(TARGET_NAME):$(TARGET_TAG)
	$(CONTAINER_ENGINE) push \
		$(TARGET_HUB)/$(TARGET_NAME):$(TARGET_TAG)
	$(CONTAINER_ENGINE) pull \
		$(TARGET_HUB)/$(TARGET_NAME):$(TARGET_TAG)
	$(CONTAINER_ENGINE) tag  \
		$(TARGET_HUB)/$(TARGET_NAME):$(TARGET_TAG) \
		$(TARGET_HUB)/${TARGET_NAME}\:latest
	$(CONTAINER_ENGINE) push \
		$(TARGET_HUB)/${TARGET_NAME}:latest

shell: # Run an interactive shell in the execution environment
	$(CONTAINER_ENGINE) run -it --rm $(TARGET_NAME):$(TARGET_TAG) /bin/bash

docs-setup: # Setup MkDocs virtualenv and dependencies
	@echo "\n\n***************************** Docs Setup... \n"
	python3 -m venv .venv-docs || true
	. .venv-docs/bin/activate; pip install -r mkdocs.yml/requirements.txt

docs-build: docs-setup # Build docs locally with MkDocs
	@echo "\n\n***************************** Docs Build... \n"
	. .venv-docs/bin/activate; mkdocs build -f mkdocs.yml/mkdocs.yml

docs-serve: docs-setup # Serve docs on localhost:8000
	@echo "\n\n***************************** Docs Serve... \n"
	. .venv-docs/bin/activate; mkdocs serve -f mkdocs.yml/mkdocs.yml -a 127.0.0.1:8000

docs-test: # Build, serve, and probe the site locally
	@echo "\n\n***************************** Docs Test... \n"
	bash scripts/test-docs-local.sh

# OpenShift/Kubernetes Tooling Targets
# Path B: Tarball install (no RHSM required)
setup-openshift-tarball: # Setup for Path B (tarball) testing
	@echo "\n\n***************************** Setting up OpenShift Tarball (Path B)... \n"
	@mkdir -p files/optional-configs
	@if [ ! -f files/optional-configs/oc-install.env ]; then \
		echo "OC_VERSION=stable-4.21" > files/optional-configs/oc-install.env; \
		echo "Created files/optional-configs/oc-install.env with OC_VERSION=stable-4.21"; \
	else \
		echo "files/optional-configs/oc-install.env already exists"; \
	fi
	@if [ -f files/optional-configs/rhsm-activation.env ]; then \
		echo "Warning: rhsm-activation.env exists. Renaming to avoid conflicts."; \
		mv files/optional-configs/rhsm-activation.env files/optional-configs/rhsm-activation.env.bak || true; \
	fi

build-openshift-tarball: setup-openshift-tarball build # Build with Path B (tarball)
	@echo "\n\n***************************** Built with OpenShift Tarball (Path B) \n"

test-openshift-tarball: build-openshift-tarball # Test Path B build
	@echo "\n\n***************************** Testing OpenShift Tarball (Path B)... \n"
	@bash scripts/test-openshift-tooling.sh $(TARGET_NAME):$(TARGET_TAG) $(CONTAINER_ENGINE)

# Path A: RPM install (requires RHSM entitlements)
setup-openshift-rhsm: # Setup for Path A (RHSM) testing
	@echo "\n\n***************************** Setting up OpenShift RHSM (Path A)... \n"
	@mkdir -p files/optional-configs
	@if [ ! -f files/optional-configs/rhsm-activation.env ]; then \
		echo "Error: files/optional-configs/rhsm-activation.env not found"; \
		echo "Create it with:"; \
		echo "  RH_ORG=<your_org>"; \
		echo "  RH_ACT_KEY=<your_activation_key>"; \
		exit 1; \
	fi
	@if [ -f files/optional-configs/oc-install.env ]; then \
		echo "Warning: oc-install.env exists. Renaming to avoid conflicts."; \
		mv files/optional-configs/oc-install.env files/optional-configs/oc-install.env.bak || true; \
	fi

build-openshift-rhsm: setup-openshift-rhsm build # Build with Path A (RHSM)
	@echo "\n\n***************************** Built with OpenShift RHSM (Path A) \n"

test-openshift-rhsm: build-openshift-rhsm # Test Path A build
	@echo "\n\n***************************** Testing OpenShift RHSM (Path A)... \n"
	@bash scripts/test-openshift-tooling.sh $(TARGET_NAME):$(TARGET_TAG) $(CONTAINER_ENGINE)

# Generic test target for OpenShift tooling (works with any image)
test-openshift-tooling: # Test OpenShift/Kubernetes tooling in built image
	@echo "\n\n***************************** Testing OpenShift Tooling... \n"
	@bash scripts/test-openshift-tooling.sh $(TARGET_NAME):$(TARGET_TAG) $(CONTAINER_ENGINE)
