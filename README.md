# Ansible Execution Environment

Example repository to build and manage multiple Ansible Execution Environments.

## Tasks

TODO: Update docs to leverage new PIP_INDEX_URL environment variable option
https://developers.redhat.com/articles/2025/01/27/how-manage-python-dependencies-ansible-execution-environments#python_dependency_management

TODO: Add info about podman signatures parameter `--remove-signatures`
The error message "Copying this image would require changing layer representation" in Podman typically arises when attempting to push or transfer an image that has certain characteristics, such as being signed or having a specific digest requirement at the destination, which would be invalidated by a change in its internal layer representation during the copy operation.

TODO: Remove `make token` and galaxy.sh, and put ENVs into execution-environment.yml and just have Makefile check if env var is set
https://developers.redhat.com/articles/2025/01/23/strategies-eliminating-ansible-hardcoded-credentials#manageability

TODO: Describe scripts
```shell
# Prepare environment variables
export AAP_TOKEN=<your_token>
source 00-envs-console.sh

# Cleanup local files and images
./01-clean.sh


```

## Quick Start

- Fork this repository
- Navigate to build server
- Clone your forked repository into build server
- (Optional) Provision build server using [script](provision.sh) to install required packages
- Customize
  - Edit dependencies `requirements.yml`, `requirements.txt`, `bindep.txt`
  - Set token environment variable `AAP_TOKEN` in the terminal window using either your Automation Hub API Token or Red Hat's console offline token
  - Edit `execution-environment.yml` accordingly
  - Edit `Makefile` top level variables
- (Optional) Cleanup with `make clean`
- (Optional) Test token with `make token`
- Build it `make build`
- Test it `make test`
- Inspect it `make inspect`
- Review it `make info`
- (Optional) Look inside `make shell`
- Publish it `make publish`
- Enjoy your day

## Environment scripts

This repository provides small helper scripts to set the environment variables used when building Ansible Execution Environments. The top-level `00-envs.sh` was split into two focused scripts so users can source the one that matches their environment.

- `00-envs-hub.sh` — For on-prem Automation Hub installations. Usage:

```shell
export AAP_TOKEN=<your_token>
source 00-envs-hub.sh my-hub.example.com
```

The hub script sets common Execution Environment variables and configures the Galaxy server URLs to point at your Automation Hub instance. It requires the host name of the hub as the single argument.

- `00-envs-console.sh` — For using Red Hat's console.redhat.com (offline token). Usage:

```shell
export AAP_TOKEN=<your_refresh_token>
source 00-envs-console.sh
```

The console script sets the common Execution Environment variables and refreshes the console offline token (it expires periodically). It configures the Galaxy server URLs to point at Red Hat's console APIs.

The original `00-envs.sh` now acts as a small helper that points to these two scripts. You can still run `source 00-envs.sh` to get the usage hints.


## Tips and Tricks

Some helpful things you might be useful while dealing with Execution Environments.

```shell
# Search registry to find latest images
podman login registry.redhat.io
podman search registry.redhat.io/ansible-automation-platform-25

# TODO: This won't work because of certified collections; move this code to test.sh

# Install ansible collections - check dependencies and newer versions
podman run -it -v $PWD:/opt/ansible registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest /bin/bash
cd /opt/ansible/ee-windows
ansible-galaxy collection install -r requirements.yml
cd /home/runner/.ansible/collections/ansible_collections/
grep -R python39 * | grep bindep.txt
grep -R suds *
ansible-galaxy collection install --upgrade -r requirements.yml

# Install system packages
microdnf install $(cat bindep.txt)
# Install python libraries
pip3 install -r requirements.txt
```

### Regression Testing

We can test that everything is working by running an Ansible Playbook in the image using `ansible-navigator`. The tool launches the container, runs the playbook and shows an interactive screen where you can watch the playbook run through. To quit the tool, use similar mechanism `:q!` like within a `vi` editor.

```shell
# Run playbook to test basic operations against new image
ansible-navigator run playbook.yml --container-engine podman --execution-environment-image ansible-ee:5.0

# Check configuration of new image
ansible-navigator config --container-engine podman --execution-environment-image ansible-ee:5.0
```

### Other things

```shell
# Explore default execution environment
ansible-navigator
# Explore an execution environment 
ansible-navigator --eei <image-name>
# Explore an execution environment - list collections
ansible-navigator --eei <image-name> collections --mode stdout

# Run `--syntax-check`
ansible-navigator run <playbook> --syntax-check --mode stdout

# Debugging
podman pull --log-level debug <image>
# Run adhoc commands
podman run --rm <image-name> <command>
# Generic command
podman run -it registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest /bin/bash
# With volume mounts
podman run -it -v $PWD:/opt/ansible registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest /bin/bash
# With volume mounts from SELinux enabled system
podman run -it -v $PWD:/opt/ansible:z registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest /bin/bash

# Build the image and tag the image
ansible-builder build --verbosity 3 --container-runtime=podman --tag ansible-ee:5.0

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
podman run -d -it --name custom-ee-supported registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest /bin/bash
podman run -d -it --name custom-ee-builder registry.redhat.io/ansible-automation-platform-25/ansible-builder-rhel9:latest /bin/bash

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

## References

The following links can help with learning about containers to building ansible execution environments:

- [microdnf showing ibrhsm-WARNING ** and Found 0 entitlement certificates](https://access.redhat.com/solutions/4643601)
- [Container Quickstarts by Red Hat's Community of Practice](https://github.com/redhat-cop/containers-quickstarts). This repository is meant to help bootstrap users of the OpenShift Container Platform to get started in building and using Source-to-Image to build applications to run in OpenShift.
- [Best Practices for successful DevSecOps](https://developers.redhat.com/articles/2022/06/15/best-practices-successful-devsecops)
- [What are image layers?](https://stackoverflow.com/a/51660942)
- [Building best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [5 Podman features to try now](https://www.redhat.com/sysadmin/podman-features-1)
- [Working with Red Hat Enterprise Linux Universal Base Images (UBI)](https://developers.redhat.com/blog/2019/05/31/working-with-red-hat-enterprise-linux-universal-base-images-ubi#)
- [Running Virtual Machines Under Vagrant on the New Mac M1/M2/M3](https://betterprogramming.pub/managing-virtual-machines-under-vagrant-on-a-mac-m1-aebc650bc12c)
- [Automation execution environments](https://www.redhat.com/en/technologies/management/ansible/automation-execution-environments)
- [Execution Environments and using awx-manage](https://github.com/ansible/awx/blob/devel/docs/execution_environments.md)
- [The Anatomy of Automation Execution Environments](https://www.redhat.com/en/blog/the-anatomy-of-automation-execution-environments)
- [AAP Docs - Using automation execution](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/using_automation_execution/index)
- [Examples of common Execution Environments](https://github.com/cloin/ee-builds)
- [Ansible Builder and Execution Environments](https://ario.cloud/posts/ansible-builder-ee)
- [Strategies for eliminating Ansible hardcoded credentials](https://developers.redhat.com/articles/2025/01/23/strategies-eliminating-ansible-hardcoded-credentials)
- [Best practices for building images that pass Red Hat Container Certification](https://developers.redhat.com/articles/2021/11/11/best-practices-building-images-pass-red-hat-container-certification)
- [How to build multi-architecture container images](https://developers.redhat.com/articles/2023/11/03/how-build-multi-architecture-container-images)
- [How to change Default execution environment or Control Plane Execution Environment](https://access.redhat.com/solutions/7116964)

- Security
  - [Using Snyk and Podman to scan container images from development to deployment](https://www.redhat.com/en/blog/using-snyk-and-podman-scan-container-images-development-deployment)
  - [DevSecOps: Image scanning in your pipelines using quay.io scanner](https://www.redhat.com/sysadmin/using-quayio-scanner)

- Ansible Collections:
  - [Ansible Automation Platform Certified and Validated Content](https://access.redhat.com/support/articles/ansible-automation-platform-certified-content)
  - [Red Hat Automation Hub - Ansible Collections](https://console.redhat.com/ansible/automation-hub)
  - [Ansible Galaxy - Search](https://galaxy.ansible.com/search?)
- Issue and resolution when using `kebernetes.core` that requires `openshift-clients` package:  
  - [How to install the 'openshift-clients' package in Openshift Custom Execution Environment?](https://access.redhat.com/solutions/6985157)  
  - [Installing the OpenShift CLI by using an RPM](https://docs.openshift.com/container-platform/4.13/cli_reference/openshift_cli/getting-started-cli.html#cli-installing-cli-rpm_cli-developer-commands)  
  - [How to download rpm packages manually from the Customer Portal?](https://access.redhat.com/solutions/6996)
  - Another workaround is using the `openshift-clients` package rpm that exists inside the AAP bundle tarball
- For Python dependency issues, install [johnnydep](https://pypi.org/project/johnnydep/) inside your current venv and leverage the tool to check various dependencies for python modules that might be causing issues. For example `johnnydep requests`.
- [Best practices for building images that pass Red Hat Container Certification](https://developers.redhat.com/articles/2021/11/11/best-practices-building-images-pass-red-hat-container-certification#)
- [How to Build Ansible Execution Environments with OpenShift Pipelines](https://cloud.redhat.com/blog/how-to-build-ansible-execution-environments-with-openshift-pipelines)
- [ansible-bender](https://github.com/ansible-community/ansible-bender) is a tool which bends containers using Ansible playbooks and turns them into container images. It has a pluggable builder selection — it is up to you to pick the tool which will be used to construct your container image. Right now the only supported builder is buildah. More to come in the future. Ansible-bender (ab) relies on Ansible connection plugins for performing builds.
- [buildah](https://github.com/containers/buildah) is a tool that facilitates building Open Container Initiative (OCI) container images. The Buildah package provides a command line tool that can be used to:
  - create a working container, either from scratch or using an image as a starting point
  - create an image, either from a working container or via the instructions in a Dockerfile
  - images can be built in either the OCI image format or the traditional upstream docker image format
  - mount a working container's root filesystem for manipulation
  - unmount a working container's root filesystem
  - use the updated contents of a container's root filesystem as a filesystem layer to create a new image
  - delete a working container or an image
  - rename a local container
- Podman
  - [Installation](https://podman.io/getting-started/installation)
  - [How to set debug logging from podman?](https://access.redhat.com/solutions/3947441)
  - [skopeo](https://github.com/containers/skopeo)

## License

[GNU General Public License v3.0](LICENSE)

## Author

John Wadleigh
