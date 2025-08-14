# Ansible Automation Platform - Makefile for Execution Environments
# Original version found on ansiblejunky @ https://github.com/ansiblejunky/ansible-execution-environment

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

ifndef $(SOURCE_TOKEN)
  $(error The environment variable ANSIBLE_HUB_TOKEN is undefined and required)
endif

.PHONY : header clean lint check build scan test publish list shell
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

lint: # Lint the repository with yamllint
	@echo "\n\n***************************** Linting... \n"
	yamllint .

token: # Test token
	@echo "\n\n***************************** Token... \n"
	envsubst < files/ansible.cfg.template > ./ansible.cfg
	mkdir -p collections
	ansible-galaxy collection download -r files/requirements.yml -p collections/


build: # Build the execution environment image
	@echo "\n\n***************************** Building... \n"
	$(CONTAINER_ENGINE) login $(SOURCE_HUB)
	if [ -a ansible.cfg ] ; \
	then \
		echo "Using existing ansible.cfg"; \
	else \
		envsubst < files/ansible.cfg.template > ./ansible.cfg; \
	fi;
	if [ -a ansible-builder.log ] ; \
	then \
		cp ansible-builder.log ansible-builder.bak.log ; \
	fi;
	ansible-builder introspect --sanitize --user-pip=files/requirements.txt --user-bindep=files/bindep.txt 2>&1 | tee ansible-builder.log
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

test: # Run the example playbook using the built container image
	@echo "\n\n***************************** Testing... \n"
	ansible-navigator run \
		files/playbook.yml \
		--container-engine $(CONTAINER_ENGINE) \
		--mode stdout \
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
