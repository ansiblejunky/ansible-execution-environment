# Ansible Automation Platform - Makefile for Execution Environments

# https://ario.cloud/posts/ansible-builder-ee
# https://earthly.dev/blog/docker-and-makefiles/

# Best practices for building images that pass Red Hat Container Certification
# https://developers.redhat.com/articles/2021/11/11/best-practices-building-images-pass-red-hat-container-certification
# Makefile Tutorial
# https://makefiletutorial.com/

# Update the tag each time you build a new image
TARGET_TAG ?= v5

# Default settings
CONTAINER_ENGINE ?= podman
VERBOSITY ?= 3
SOURCE_HUB ?= registry.redhat.io
SOURCE_USERNAME ?= jwadleig
TARGET_HUB ?= quay.io
TARGET_USERNAME ?= jwadleig
TARGET_NAME ?= ansible-ee-minimal

# IMPROVEMENTS ...
#TODO: Remove TARGET_USERNAME somehow?
#TODO: Test if galaxy tokens are valid/expired before building
#TODO: See about adding info (LABELS) to the released image on Quay.io (packages, ansible-core version, collections, python deps, etc)
#TODO: Raise error when "Warning" is shown from introspect command in build section
#TODO: Decide to include scanning of original container image from Red Hat
#curl -o `basename $IMAGE_NAME`.json https://quay.io/api/v1/repository/$IMAGE_NAME/manifest/$IMAGE_DIGEST/security?vulnerabilities=true
# Workaround using `--raw` to get digest https://github.com/containers/skopeo/issues/634
# digest := $(shell (skopeo inspect --raw docker://$(BASE_IMAGE) | jq -r .manifests[].digest))
# check: # Check base images for security vulnerabilities
# 	@echo "\n\n***************************** Checking... \n"
# 	skopeo login $(BASE_REGISTRY)
# 	echo $(digest)

.PHONY : header clean lint check build scan test publish list shell
all: header clean lint build test publish

header:
	@echo "\n\n***************************** Ansible Automation Platform - Makefile for Execution Environments \n"

clean: # Clean temporary files, folders and images
	@echo "\n\n***************************** Cleaning... \n"
	rm -rf context
	rm -rf ansible-navigator.log
	$(CONTAINER_ENGINE) image prune -a -f

lint: # Lint the repository with yamllint
	@echo "\n\n***************************** Linting... \n"
	yamllint .

build: # Build the execution environment image
	@echo "\n\n***************************** Building... \n"
	$(CONTAINER_ENGINE) login -u $(SOURCE_USERNAME) $(SOURCE_HUB)
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


publish: # Publish the image with proper tags to container registry
	@echo "\n\n***************************** Publishing... \n"
	$(CONTAINER_ENGINE) login -u $(TARGET_USERNAME) $(TARGET_HUB)
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

info: # List information about the published container image
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

shell: # Run an interactive shell in the execution environment
	$(CONTAINER_ENGINE) run -it --rm $(TARGET_NAME):$(TARGET_TAG) /bin/bash
