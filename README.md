# Ansible Execution Environments Demo

Basic information to help you get familiar with Ansible Execution Environments and the latest Ansible Automation Platform.

General information on [Ansible Controller](https://docs.ansible.com/automation-controller/latest/html/userguide/index.html) and the related [execution environments](https://docs.ansible.com/automation-controller/latest/html/userguide/ee_reference.html).

## Requirements

- Install container tool of choice (docker / podman)
- skopio [https://github.com/containers/skopeo/blob/main/README.md]
- ansible-navigator (includes ansible-builder, etc)
- yaml-lint
- jq

Example using Mac OS:

```bash
# Install docker and docker desktop
brew install --cask docker
# Install podman https://podman.io/ and podman-desktop https://podman-desktop.io/
brew install podman
brew install podman-desktop

# Install pyenv
brew install pyenv
# Prepare python environment
pyenv install 3.10.2
pyenv activate 3.10.2 ansible
# Install ansible-navigator and related tools
pip install ansible-navigator[ansible-core]
```

## Login

Ensure you login to the registry of choice using podman/docker command `podman login <registry_url>`

Automation Hub Registry (hub.example.com):

- Ensure docker/podman is authorized to access registry since Automation Hub uses self-signed certificates (see info at bottom of this article)
- Run the CLI login command `podman login hub.example.com:443`

Quay Registry (quay.io):

- Ensure you authorize docker/podman with this registry
- Go to https://quay.io/ and login or create an account
- Navigate to top-right for Account Settings
- Select the tool icon on the left
- Set the Docker/Podman CLI Password to enable encrypted passwords
- Generate the encryped password (re-enter the password)
- Select the option "Docker Login" or "Podman Login" to get the CLI command
- Run the CLI login command to have docker/podman authorized to pull/push images

Red Hat Registry (registry.redhat.io):

- Ensure you perform `docker login` command to authorize with this registry.
- Go to https://access.redhat.com/terms-based-registry/ and create a registry service account (if not already created)
- Drill down on existing service account
- Select the tab "Docker Login" to get the CLI command for both docker/podman
- Run the CLI login command to have docker/podman authorized to pull/push images
- [Troubleshooting Authentication Issues with registry.redhat.io](https://access.redhat.com/articles/3560571)

Docker Hub (hub.docker.com):

- Create a free account on the website
- Login to the website
- Run the CLI login command `docker login` with your credentials

## Pull the Image

Now that you have authenticated with a registry, you can pull down images from that registry. For example, you might want to pull down the Ansible base images. You can find official Ansible container images using `https://catalog.redhat.com/software/containers/search`.

```bash
# Pull base images for Ansible from registry.redhat.io
docker pull registry.redhat.io/ansible-automation-platform-22/ee-minimal-rhel8:latest
docker pull registry.redhat.io/ansible-automation-platform-22/ee-supported-rhel8:latest
docker pull registry.redhat.io/ansible-automation-platform-22/ansible-builder-rhel8:latest

# Pull images from hub.docker.com
docker login
docker pull hello-world
docker run hello-world
```

## Build the Image

Ansible playbooks will be executed from a container image. We define our "golden" image using a build definition file named `execution-environment.yml`.
The image is built using that template file and running the `ansible-builder` tool.

Let's first define our execution environment using yaml. [Here is an example file from this repository](./execution-environment.yml).

Now let's run `ansible-builder` to create the image based on our template. Note that Podman is used by default to build images but we will use Docker instead. Also the default name and tag for the container image being built is `ansible-execution-env:latest` but it's highly recommended that you avoid using "latest" and set your own tag/version using the `--tag` argument.

```yaml
# Set tokens using environment variables
export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN="token_value"
export ANSIBLE_GALAXY_SERVER_COMMUNITY_TOKEN="token_value"

# Generate ansible.cfg using template
envsubst < ansible.cfg.template > ansible.cfg

# Test tokens
mkdir collections
ansible-galaxy collection download -r requirements.yml -p collections/
rm -rf collections

# Build the image and tag the image
ansible-builder build --verbosity 3 --container-runtime=docker --tag ansible-ee:5.0
# List images
$ docker image list
REPOSITORY                            TAG             IMAGE ID       CREATED         SIZE
ansible-ee                 5.0             9fec21fe39be   2 hours ago     987MB
```

## Scan the Image

Don't forget security! Use the docker command to scan the image you built to ensure it's safe to use. To use this feature you need to login to Docker Hub and Synk (see below commands).

```yaml
# Login to Docker Hub
docker login

# Login to Synk
docker scan --login

# Scan the image
docker scan ansible-execution-env:5.0
```

## Run the Image

We can test that everything is working by running an Ansible Playbook in the image using `ansible-navigator`. The tool launches the container, runs the playbook and shows an interactive screen where you can watch the playbook run through. To quit the tool, use similar mechanism `:q!` like within a `vi` editor.

```yaml
ansible-navigator run playbook.yml --container-engine docker --execution-environment-image ansible-ee:5.0

ansible-navigator config --container-engine docker --execution-environment-image ansible-ee:5.0
```

## Push the Image

Once you have built the image locally, tested it, and scanned it for security issues - you are now ready to push the image to a registry of choice.

```bash
# Example using quay.io
docker login quay.io
docker tag ansible-ee:5.0 quay.io/jwadleig/ansible-ee:5.0
docker push quay.io/jwadleig/ansible-ee:5.0

# Example using onprem Automation Hub
podman login hub.example.com:443
podman tag ansible-ee:6.0 hub.example.com:443/ansible-ee
podman push hub.example.com:443/ansible-ee --remove-signatures
```

## Migration of Virtual Environments

Leverage the following utils to help migrate pre-existing python virtual environments to execution environments.

[Redhat Communities of Practice Execution Environment Utilities Collection](https://github.com/redhat-cop/ee_utilities)

## Tips and Tricks

OpenShift pipeline:

[How to Build Ansible Execution Environments with OpenShift Pipelines](https://cloud.redhat.com/blog/how-to-build-ansible-execution-environments-with-openshift-pipelines)

Default execution environment that ansible-navigator uses when not specified: [quay.io/ansible/creator-ee](https://github.com/ansible/creator-ee)

Examine execution environment using ansible-navigator:
`ansible-navigator --eei <image-name>`

Extract list of collections from existing execution environment:
`ansible-navigator --eei <image-name> collections --mode stdout`

Use Credentials within `ansible-navigator` tool:

- [How Do I Use Ansible Tower's Credential Parameters (Machine, Network, Cloud) in my Playbook?](https://access.redhat.com/solutions/3332591)
- Mount the file(s) using `--eev` parameter on ansible-navigator
`--eev  --execution-environment-volume-mounts    Specify volume to be bind mounted within an execution environment (--eev /home/user/test:/home/user/test:Z)`

How to run `--syntax-check` using `ansible-navigator`:

`ansible-navigator run <playbook> --syntax-check --mode stdout`

Start shell session inside container image:

```yaml
docker run -it registry.redhat.io/ansible-automation-platform-22/ee-minimal-rhel8:latest /bin/bash
```

Run adhoc commands inside image:

```yaml
podman run --rm <image-name> <command>
```

Change the yum and pip repositories within the base and builder images:

```shell
# Create yum repository file locally
cat > ubi.repo <<EOF
[rhel-8-for-x86_64-appstream-rpms]
baseurl = http://x.x.x.x/rpms/rhel-8-for-x86_64-appstream-rpms
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
[rhel-8-for-x86_64-baseos-rpms]
baseurl = http://x.x.x.x/rpms/rhel-8-for-x86_64-baseos-rpms
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF

# Create pip configuration file locally
cat > pip.conf <<EOF
[global]
index-url = https://artifactory.acme.com/artifactory/api/pypi/pypi/simple
trusted-host = artifactory.acme.com
EOF

# Then run the containers
podman run -d -it --name custom-ee-supported registry.redhat.io/ansible-automation-platform-22/ee-supported-rhel8:latest /bin/bash
podman run -d -it --name custom-ee-builder registry.redhat.io/ansible-automation-platform-22/ansible-builder-rhel8:latest /bin/bash

# Then copy the yum repo file into the containers
podman cp ubi.repo custom-ee-supported:/etc/yum.repos.d/
podman cp ubi.repo custom-ee-builder:/etc/yum.repos.d/

# Then copy the pip config file to set the global pip configuration https://pip.pypa.io/en/stable/topics/configuration/
podman cp pip.conf custom-ee-supported:/etc/
podman cp pip.conf custom-ee-builder:/etc/

#Then stop the containers
podman stop -a

#Then commit the containers
podman commit --message "Replaced yum repos" --format docker --author "ACME Company" <containerID> <image>

#Then push the containers
podman push <image-name> quay.io/username/myimage
```

## Tools

ansible-builder:

- [Introduction to Ansible Builder](https://www.ansible.com/blog/introduction-to-ansible-builder)
- [Ansible Builder - Guide](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.1/html/ansible_builder_guide/assembly-using-builder)
- [Ansible Builder - Read The Docs](https://ansible-builder.readthedocs.io/en/latest/index.html)
- [Ansible Builder - Source Code](https://github.com/ansible/ansible-builder)

ansible-navigator:

- [Ansible Navigator Creator Guide](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.0-ea/html-single/ansible_navigator_creator_guide/index)
- [Introduction to Ansible Runner](https://ansible-runner.readthedocs.io/en/stable/intro/)
- [Ansible Navigator - Source Code](https://github.com/ansible/ansible-navigator/)
- [Ansible Navigator - Settings](https://github.com/ansible/ansible-navigator/blob/main/docs/settings.rst)

ansible-bender:

[ansible-bender](https://github.com/ansible-community/ansible-bender) is a tool which bends containers using Ansible playbooks and turns them into container images. It has a pluggable builder selection — it is up to you to pick the tool which will be used to construct your container image. Right now the only supported builder is buildah. More to come in the future. Ansible-bender (ab) relies on Ansible connection plugins for performing builds.

buildah:

[buildah](https://github.com/containers/buildah) is a tool that facilitates building Open Container Initiative (OCI) container images. The Buildah package provides a command line tool that can be used to:

- create a working container, either from scratch or using an image as a starting point
- create an image, either from a working container or via the instructions in a Dockerfile
- images can be built in either the OCI image format or the traditional upstream docker image format
- mount a working container's root filesystem for manipulation
- unmount a working container's root filesystem
- use the updated contents of a container's root filesystem as a filesystem layer to create a new image
- delete a working container or an image
- rename a local container

podman:

- [Installation](https://podman.io/getting-started/installation)
- [How to set debug logging from podman?](https://access.redhat.com/solutions/3947441)
- Debugging: `podman pull --log-level debug <image>`

docker:

skopeo:

docker:

[The Docker Ecosystem: An Introduction to Common Components](https://www.digitalocean.com/community/tutorials/the-docker-ecosystem-an-introduction-to-common-components)

## References

General:

- [microdnf showing ibrhsm-WARNING ** and Found 0 entitlement certificates](https://access.redhat.com/solutions/4643601)
- [Container Quickstarts by Red Hat's Community of Practice](https://github.com/redhat-cop/containers-quickstarts). This repository is meant to help bootstrap users of the OpenShift Container Platform to get started in building and using Source-to-Image to build applications to run in OpenShift.
- [Best Practices for successful DevSecOps](https://developers.redhat.com/articles/2022/06/15/best-practices-successful-devsecops)
- [What are image layers?](https://stackoverflow.com/a/51660942)
- [Best Practices for Writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

Execution Environments:

- [What are Red Hat Ansible Automation Platform automation execution environments?](https://www.redhat.com/en/technologies/management/ansible/automation-execution-environments)
- [Automation Controller - Execution Environments](https://docs.ansible.com/automation-controller/latest/html/userguide/execution_environments.html)
- [Execution Environment Setup Reference](https://docs.ansible.com/automation-controller/latest/html/userguide/ee_reference.html#execution-environment-setup-reference)
