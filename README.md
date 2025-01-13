# Ansible Execution Environments Demo

Basic information to help you get familiar with Ansible Execution Environments and the latest Ansible Automation Platform.

General information on [Ansible Controller](https://docs.ansible.com/automation-controller/latest/html/userguide/index.html) and the related [execution environments](https://docs.ansible.com/automation-controller/latest/html/userguide/ee_reference.html).

## Quick Start

- Navigate to build server
- Clone down this repository
- Customize
  - Edit dependencies `requirements.yml`, `requirements.txt`, `bindep.txt`
  - Update tokens
  - Edit `execution-environment.yml` accordingly
  - Edit `Makefile`
- Build it `make build`
- Publish it `make publish`
- Destroy Vagrant machine `vagrant destroy`
- Enjoy your day

## Requirements

### Build server

This repository uses `vagrant` to spin up a RHEL server and then [provisions](files/provision.sh) it.

```shell
# Start vagrant machine
vagrant up
# Connect to vagrant machine
vagrant ssh
# Prepare Ansible environment
source ~/ansible/bin/activate && cd /vagrant
```

### Tokens

To access the Ansible content (collections) and build execution environments, you'll need to provide authentication using a token. This is configured within the `ansible.cfg` in the root folder. To generate this file, use the template [ansible.cfg.template](./files/ansible.cfg.template) which authenticates to both Automation Hub and Ansible Galaxy. This means we will always pull from Automation Hub first, but if not found we default to using Ansible Galaxy for content.

First, set the following environment variables with the appropriate token strings. And then use the `envsubst` command to generate the necessary `ansible.cfg` file.

```shell
# Automation Hub token https://console.redhat.com/ansible/automation-hub/token
export ANSIBLE_HUB_TOKEN=

# Generate ansible.cfg file
envsubst < files/ansible.cfg.template > ./ansible.cfg
```

### Image registry

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
podman pull registry.redhat.io/ansible-automation-platform-24/ee-29-rhel8:latest
podman pull registry.redhat.io/ansible-automation-platform-24/ee-minimal-rhel8:latest
podman pull registry.redhat.io/ansible-automation-platform-24/ee-supported-rhel8:latest

# Pull images from hub.docker.com
podman login hub.docker.com
podman pull hello-world
podman run hello-world
```

## Build the Image

Ansible playbooks will be executed from a container image. We define our "golden" image using a build definition file named `execution-environment.yml`.
The image is built using that template file and running the `ansible-builder` tool.

Let's first define our execution environment using yaml. [Here is an example file from this repository](./execution-environment.yml).

Now let's run `ansible-builder` to create the image based on our template. Note that Podman is used by default to build images but we will use Docker instead. Also the default name and tag for the container image being built is `ansible-execution-env:latest` but it's highly recommended that you avoid using "latest" and set your own tag/version using the `--tag` argument.

```yaml
# Set tokens using environment variables
export ANSIBLE_HUB_TOKEN="token_value"

# Generate ansible.cfg using template
envsubst < files/ansible.cfg.template > ./ansible.cfg

# Test tokens
mkdir collections
ansible-galaxy collection download -r requirements.yml -p collections/
rm -rf collections

# Build the image and tag the image
ansible-builder build --verbosity 3 --container-runtime=podman --tag ansible-ee:5.0
# List images
$ podman image list
REPOSITORY                            TAG             IMAGE ID       CREATED         SIZE
ansible-ee                 5.0             9fec21fe39be   2 hours ago     987MB
```

## Scan the Image

It's important to scan your image for vulnerabilities.  Below are a couple articles showing how to do that. The recommendation is to implement this inside the [Makefile](./Makefile) in this repository so you can run it easily as part of your pipeline.

- [Using Snyk and Podman to scan container images from development to deployment](https://www.redhat.com/en/blog/using-snyk-and-podman-scan-container-images-development-deployment)
- [DevSecOps: Image scanning in your pipelines using quay.io scanner](https://www.redhat.com/sysadmin/using-quayio-scanner)

## Test the Image

We can test that everything is working by running an Ansible Playbook in the image using `ansible-navigator`. The tool launches the container, runs the playbook and shows an interactive screen where you can watch the playbook run through. To quit the tool, use similar mechanism `:q!` like within a `vi` editor.

```shell
# Run playbook to test basic operations against new image
ansible-navigator run playbook.yml --container-engine podman --execution-environment-image ansible-ee:5.0

# Check configuration of new image
ansible-navigator config --container-engine podman --execution-environment-image ansible-ee:5.0
```

## Publish the Image

Once you have built the image locally, tested it, and scanned it for security issues - you are now ready to publish the image to a registry of choice.

```bash
# Example using quay.io
podman login quay.io
podman tag ansible-ee:5.0 quay.io/jwadleig/ansible-ee:5.0
podman push quay.io/jwadleig/ansible-ee:5.0

# Example using onprem Automation Hub
podman login hub.example.com:443
podman tag ansible-ee:6.0 hub.example.com:443/ansible-ee
podman push hub.example.com:443/ansible-ee --remove-signatures
```

## Tips and Tricks

Building:

- [How to build multi-architecture container images](https://developers.redhat.com/articles/2023/11/03/how-build-multi-architecture-container-images)

Migration of Python Virtual Environments:

- [Redhat Communities of Practice Execution Environment Utilities Collection](https://github.com/redhat-cop/ee_utilities)

Ansible Collection issues:

- Search for Ansible Collections and versions using these links:
  - [Ansible Automation Platform Certified and Validated Content](https://access.redhat.com/support/articles/ansible-automation-platform-certified-content)
  - [Red Hat Automation Hub - Ansible Collections](https://console.redhat.com/ansible/automation-hub)
  - [Ansible Galaxy - Search](https://galaxy.ansible.com/search?)
- Issue and resolution when using `kebernetes.core` that requires `openshift-clients` package:  
  - [How to install the 'openshift-clients' package in Openshift Custom Execution Environment?](https://access.redhat.com/solutions/6985157)  
  - [Installing the OpenShift CLI by using an RPM](https://docs.openshift.com/container-platform/4.13/cli_reference/openshift_cli/getting-started-cli.html#cli-installing-cli-rpm_cli-developer-commands)  
  - [How to download rpm packages manually from the Customer Portal?](https://access.redhat.com/solutions/6996)
  - Another workaround is using the `openshift-clients` package rpm that exists inside the AAP bundle tarball

Python dependency issues:

- Install [johnnydep](https://pypi.org/project/johnnydep/) inside your current venv and leverage the tool to check various dependencies for python modules that might be causing issues. For example `johnnydep requests`.

Image building and customization:

- [Best practices for building images that pass Red Hat Container Certification](https://developers.redhat.com/articles/2021/11/11/best-practices-building-images-pass-red-hat-container-certification#)

Pipelines:

- [How to Build Ansible Execution Environments with OpenShift Pipelines](https://cloud.redhat.com/blog/how-to-build-ansible-execution-environments-with-openshift-pipelines)

Ansible Navigator:

- Default execution environment that ansible-navigator uses when not specified: [quay.io/ansible/creator-ee](https://github.com/ansible/creator-ee)
- Examine execution environment using ansible-navigator: `ansible-navigator --eei <image-name>`
- Extract list of collections from existing execution environment: `ansible-navigator --eei <image-name> collections --mode stdout`
- Use Credentials within `ansible-navigator` tool:
  - [How Do I Use Ansible Tower's Credential Parameters (Machine, Network, Cloud) in my Playbook?](https://access.redhat.com/solutions/3332591)
  - Mount the file(s) using `--eev` parameter on ansible-navigator: `--eev  --execution-environment-volume-mounts    Specify volume to be bind mounted within an execution environment (--eev /home/user/test:/home/user/test:Z)`
- How to run `--syntax-check` using `ansible-navigator`:

```shell
ansible-navigator run <playbook> --syntax-check --mode stdout`
```

- Start shell session inside container image:

```shell
podman run -it registry.redhat.io/ansible-automation-platform-24/ee-minimal-rhel9:latest /bin/bash
```

- Run adhoc commands inside image:

```shell
podman run --rm <image-name> <command>
```

- Change the yum and pip repositories within the base images:

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
podman run -d -it --name custom-ee-supported registry.redhat.io/ansible-automation-platform-24/ee-supported-rhel8:latest /bin/bash
podman run -d -it --name custom-ee-builder registry.redhat.io/ansible-automation-platform-24/ansible-builder-rhel8:latest /bin/bash

# Then copy the yum repo file into the containers
podman cp ubi.repo custom-ee-supported:/etc/yum.repos.d/
podman cp ubi.repo custom-ee-builder:/etc/yum.repos.d/

# Then copy the pip config file to set the global pip configuration https://pip.pypa.io/en/stable/topics/configuration/
podman cp pip.conf custom-ee-supported:/etc/
podman cp pip.conf custom-ee-builder:/etc/

#Then stop the containers
podman stop -a

#Then commit the containers
podman commit --message "Replaced yum repos" --author "ACME Company" <containerID> <image>

#Then push the containers
podman push <image-name> quay.io/username/myimage
```

- Search for images

The following example searches for images and then checks collections, system packages and python packages manually before we run the ansible-builder command.

```shell
# Login to vagrant build server
vagrant ssh
source ~/ansible/bin/activate
cd /vagrant

# Login to registry
podman login registry.redhat.io
# Search registry to find latest images
# https://docs.podman.io/en/stable/markdown/podman-search.1.html
podman search ansible-automation-platform-24

# Pull image and start container
podman run -it --rm registry.redhat.io/ansible-automation-platform-24/ee-minimal-rhel9:latest /bin/bash

# Check dependencies for collections
ansible-galaxy collection install -r requirements.yml
cd /home/runner/.ansible/collections/ansible_collections/
grep -R python39 * | grep bindep.txt
grep -R suds *
# Look at potential newer versions of the collections
ansible-galaxy collection install --upgrade -r requirements.yml

# Install windows packages
microdnf install krb5-libs krb5-workstation krb5-devel
# Install Python 3.8 developer tools
microdnf install vi git rsync unzip tar sudo gcc openssl openssl-devel gcc-c++ dnf libpq-devel python38-devel glibc-headers libcurl-devel libssh-devel jq python3-Cython python3-devel openldap-devel
# Install Python 3.9 developer tools
microdnf install vi git rsync unzip tar sudo gcc openssl openssl-devel gcc-c++ dnf libpq-devel python39-devel glibc-headers libcurl-devel libssh-devel jq python3-Cython python3-devel openldap-devel
# Test the installation of required python libraries
pip3 install -r requirements.txt
```

## Tools

ansible-builder:

- [Introduction to Ansible Builder](https://www.ansible.com/blog/introduction-to-ansible-builder)
- [Ansible Builder - Guide](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.1/html/ansible_builder_guide/assembly-using-builder)
- [Ansible Builder - Read The Docs](https://ansible-builder.readthedocs.io/en/latest/index.html)
- [Ansible Builder - Source Code](https://github.com/ansible/ansible-builder)
- [Ansible Builder - Releases](https://github.com/ansible/ansible-builder/releases)

ansible-navigator:

- [Ansible Navigator Documentation](https://ansible.readthedocs.io/projects/navigator/)
- [Ansible Navigator Creator Guide](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.4/html/automation_content_navigator_creator_guide/index)
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

skopeo:

- [skopeo](https://github.com/containers/skopeo)

## References

General:

- [microdnf showing ibrhsm-WARNING ** and Found 0 entitlement certificates](https://access.redhat.com/solutions/4643601)
- [Container Quickstarts by Red Hat's Community of Practice](https://github.com/redhat-cop/containers-quickstarts). This repository is meant to help bootstrap users of the OpenShift Container Platform to get started in building and using Source-to-Image to build applications to run in OpenShift.
- [Best Practices for successful DevSecOps](https://developers.redhat.com/articles/2022/06/15/best-practices-successful-devsecops)
- [What are image layers?](https://stackoverflow.com/a/51660942)
- [Best Practices for Writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [5 Podman features to try now](https://www.redhat.com/sysadmin/podman-features-1)
- [Working with Red Hat Enterprise Linux Universal Base Images (UBI)](https://developers.redhat.com/blog/2019/05/31/working-with-red-hat-enterprise-linux-universal-base-images-ubi#)
- [Running Virtual Machines Under Vagrant on the New Mac M1/M2/M3](https://betterprogramming.pub/managing-virtual-machines-under-vagrant-on-a-mac-m1-aebc650bc12c)

Execution Environments:

- [What are Red Hat Ansible Automation Platform automation execution environments?](https://www.redhat.com/en/technologies/management/ansible/automation-execution-environments)
- [AWX - Execution Environments and using awx-manage](https://github.com/ansible/awx/blob/devel/docs/execution_environments.md)
- [Blog - The Anatomy of Automation Execution Environments](https://www.ansible.com/blog/the-anatomy-of-automation-execution-environments)
- [Automation Controller - Execution Environments](https://docs.ansible.com/automation-controller/latest/html/userguide/execution_environments.html)
- [Execution Environment Setup Reference](https://docs.ansible.com/automation-controller/latest/html/userguide/ee_reference.html#execution-environment-setup-reference)

Makefiles:

- [Docker and Makefiles: Building and Pushing Images with Make](https://earthly.dev/blog/docker-and-makefiles/)

## License

[GNU General Public License v3.0](LICENSE)

## Author

John Wadleigh
