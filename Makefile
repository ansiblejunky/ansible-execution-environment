# Ansible Automation Platform - Makefile for Execution Environments

# https://ario.cloud/posts/ansible-builder-ee
# https://earthly.dev/blog/docker-and-makefiles/

# Best practices for building images that pass Red Hat Container Certification
# https://developers.redhat.com/articles/2021/11/11/best-practices-building-images-pass-red-hat-container-certification
# Makefile Tutorial
# https://makefiletutorial.com/

# Generic parameters
CONTAINER_ENGINE ?= podman
VERBOSITY ?= 3

# Source parameters
BASE_REGISTRY ?= registry.redhat.io
BASE_APPLICATION ?= ansible-automation-platform
BASE_VERSION ?= 22
BASE_NAME ?= ee-minimal
BASE_OS ?= rhel8
BASE_IMAGE ?= $(BASE_REGISTRY)/$(BASE_APPLICATION)-$(BASE_VERSION)/$(BASE_NAME)\-$(BASE_OS)

# Target parameters
REGISTRY_HUB ?= quay.io
REGISTRY_USERNAME ?= jwadleig
CONTAINER_NAME ?= ansible-$(BASE_NAME)
#TODO: Use hash? or what?
GIT_HASH ?= $(shell git log --format="%h" -n 1)
#CONTAINER_TAG ?= 1.0.0
CONTAINER_TAG ?= $(GIT_HASH)

.PHONY : header clean lint check build scan test publish list shell
all: header clean lint build test publish

header:
	@echo "\n\n***************************** Ansible Automation Platform - Makefile for Execution Environments \n"

clean: # Clean temporary files, folders and images
	@echo "\n\n***************************** Cleaning... \n"
	rm -rf context
	rm -rf ansible-navigator.log
	$(CONTAINER_ENGINE) image prune -a -f

#TODO: Test if tokens are valid/expired before building
lint: # Lint the repository with yamllint
	@echo "\n\n***************************** Linting... \n"
	yamllint .

#TODO: Decide to include scanning of original container image from Red Hat
#curl -o `basename $IMAGE_NAME`.json https://quay.io/api/v1/repository/$IMAGE_NAME/manifest/$IMAGE_DIGEST/security?vulnerabilities=true
# Workaround using `--raw` to get digest https://github.com/containers/skopeo/issues/634
digest := $(shell (skopeo inspect --raw docker://$(BASE_IMAGE) | jq -r .manifests[].digest))
check: # Check base images for security vulnerabilities
	@echo "\n\n***************************** Checking... \n"
	skopeo login $(BASE_REGISTRY)
	echo $(digest)
	
#TODO: Check `Warning: failed to parse requirements from user, error: Parse error at "'\\>=0.3.0'": Expected string_end` from introspect command
#		add linting for bindep.txt, requirements.txt and requirements.yml (yamllint)
#		raise error when "Warning" is shown from introspect command
build: # Build the execution environment image
	@echo "\n\n***************************** Building... \n"
	if [ -a ansible-builder.log ] ; \
	then \
		cp ansible-builder.log ansible-builder.bak.log ; \
	fi;
	ansible-builder introspect --sanitize --user-pip=requirements.txt --user-bindep=bindep.txt 2>&1 | tee ansible-builder.log
	ansible-builder build \
		--build-arg EE_BASE_IMAGE=$(BASE_IMAGE) \
		--tag $(CONTAINER_NAME):$(CONTAINER_TAG) \
		--verbosity $(VERBOSITY) \
		--container-runtime $(CONTAINER_ENGINE) 2>&1 | tee -a ansible-builder.log

scan: # Scan image for vulnerabilities https://www.redhat.com/sysadmin/using-quayio-scanner
	@echo "\n\n***************************** Scanning... \n"
	echo .

inspect: # Inspect built image to show information
	@echo "\n\n***************************** Inspecting... \n"
	$(CONTAINER_ENGINE) inspect $(CONTAINER_NAME):$(CONTAINER_TAG)

test: # Run the example playbook using the built container image
	@echo "\n\n***************************** Testing... \n"
	ansible-navigator run \
		playbook.yml \
		--container-engine $(CONTAINER_ENGINE) \
		--mode stdout \
		--execution-environment-image $(CONTAINER_NAME):$(CONTAINER_TAG)


#TODO: See about adding info (LABELS) to the released image on Quay.io (packages, ansible-core version, collections, python deps, etc)
publish: # Publish the image with proper tags to container registry
	@echo "\n\n***************************** Publishing... \n"
	$(CONTAINER_ENGINE) login $(REGISTRY_HUB)
	$(CONTAINER_ENGINE) tag  \
		$(CONTAINER_NAME):$(CONTAINER_TAG) $(CONTAINER_NAME):latest
	$(CONTAINER_ENGINE) tag  \
		$(CONTAINER_NAME):$(CONTAINER_TAG) \
		$(REGISTRY_HUB)/${REGISTRY_USERNAME}/$(CONTAINER_NAME):$(CONTAINER_TAG)
	$(CONTAINER_ENGINE) push \
		$(REGISTRY_HUB)/${REGISTRY_USERNAME}/$(CONTAINER_NAME):$(CONTAINER_TAG)
	$(CONTAINER_ENGINE) pull \
		$(REGISTRY_HUB)/${REGISTRY_USERNAME}/$(CONTAINER_NAME):$(CONTAINER_TAG)
	$(CONTAINER_ENGINE) tag  \
		$(REGISTRY_HUB)/${REGISTRY_USERNAME}/$(CONTAINER_NAME):$(CONTAINER_TAG) \
		$(REGISTRY_HUB)/${REGISTRY_USERNAME}/${CONTAINER_NAME}\:latest
	$(CONTAINER_ENGINE) push \
		$(REGISTRY_HUB)/${REGISTRY_USERNAME}/${CONTAINER_NAME}:latest

info: # List information about the published container image
	@echo "\n\n***************************** Image Layers ... \n"
	$(CONTAINER_ENGINE) history --human $(CONTAINER_NAME):$(CONTAINER_TAG)
	@echo "\n\n***************************** Ansible Version ... \n"
	$(CONTAINER_ENGINE) container run -it --rm $(CONTAINER_NAME):$(CONTAINER_TAG) ansible --version
	@echo "\n\n***************************** Ansible Collections ... \n"
	$(CONTAINER_ENGINE) container run -it --rm $(CONTAINER_NAME):$(CONTAINER_TAG) ansible-galaxy collection list
	@echo "\n\n***************************** Python Modules ... \n"
	$(CONTAINER_ENGINE) container run -it --rm $(CONTAINER_NAME):$(CONTAINER_TAG) pip3 list --format freeze
	@echo "\n\n***************************** System Packages ... \n"
	$(CONTAINER_ENGINE) container run -it --rm $(CONTAINER_NAME):$(CONTAINER_TAG) rpm -qa

shell: # Run an interactive shell in the execution environment
	$(CONTAINER_ENGINE) run -it --rm $(CONTAINER_NAME):latest /bin/bash