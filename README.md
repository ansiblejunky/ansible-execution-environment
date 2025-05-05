# Ansible Execution Environment

Example repository to build Ansible Execution Environments using a Makefile.

## Documentation

- [Bootstrap Environment Guide](docs/bootstrap-guide.md) - Setup and configuration guide
- [Architecture Decision Records](docs/adrs/)
  - [ADR-0006: Authentication Flow and Token Handling](docs/adrs/0006-authentication-flow-and-token-handling.md)

TODO: Update docs to leverage new PIP_INDEX_URL environment variable option
https://developers.redhat.com/articles/2025/01/27/how-manage-python-dependencies-ansible-execution-environments#python_dependency_management

## Quick Start

- Navigate to build server
- Optionally provision build server using [script](files/provision.sh)
- Clone this repository
- Customize
  - Edit dependencies `requirements.yml`, `requirements.txt`, `bindep.txt`
  - Set up environment variables using the provided template:
    ```bash
    cp .env-example .env
    # Edit the .env file with your specific values
    vim .env
    ```
  - Or set token environment variable manually: `export ANSIBLE_HUB_TOKEN=your-token-here`
  - Edit `execution-environment.yml` accordingly
  - Edit `Makefile` variables if needed (though .env is preferred)
- Check your environment settings with `make env`
- Cleanup with `make clean`
- Test token with `make token`
- Build it `make build`
- Test it `make test`
- Inspect it `make inspect`
- Review it `make info`
- (Optional) Look inside `make shell`
- Publish it `make publish`
- Enjoy your day

## Find and Test Image

Search for images and then checks collections, system packages and python packages manually before we run the ansible-builder command.

```shell
# Login to registry
podman login registry.redhat.io
# Search registry to find latest images
podman search registry.redhat.io/ansible-automation-platform-25
# Pull image and start container with volume mounts
podman run -it -v $PWD:/opt/ansible registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest /bin/bash

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

## Security

It's important to scan your image for vulnerabilities.  Below are a couple articles showing how to do that. The recommendation is to implement this inside the [Makefile](./Makefile) in this repository so you can run it easily as part of your pipeline.

- [Using Snyk and Podman to scan container images from development to deployment](https://www.redhat.com/en/blog/using-snyk-and-podman-scan-container-images-development-deployment)
- [DevSecOps: Image scanning in your pipelines using quay.io scanner](https://www.redhat.com/sysadmin/using-quayio-scanner)

## Regression Testing

We can test that everything is working by running an Ansible Playbook in the image using `ansible-navigator`. The tool launches the container, runs the playbook and shows an interactive screen where you can watch the playbook run through. To quit the tool, use similar mechanism `:q!` like within a `vi` editor.

```shell
# Run playbook to test basic operations against new image
ansible-navigator run playbook.yml --container-engine podman --execution-environment-image ansible-ee:5.0

# Check configuration of new image
ansible-navigator config --container-engine podman --execution-environment-image ansible-ee:5.0
```

### Container-Based Testing

If your environment doesn't have all required tools installed, you can use our container-based testing scripts:

```shell
# Basic testing without AAP requirements
./files/container-test.sh

# Testing with AAP integration
./files/test-aap-integration.sh
```

These scripts:
1. Create temporary test playbooks
2. Pull a container image with all required tools
3. Run the tests inside the container
4. Report the results
5. Clean up temporary files

This approach ensures consistent testing even when your host system doesn't have all prerequisites installed.

> **Note**: Red Hat execution environments use `pip3` instead of `pip` for Python package management. Our testing scripts are configured to work with this difference.

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
# Generic command
podman run -it registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest /bin/bash
# With volume mounts
podman run -it -v $PWD:/opt/ansible registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest /bin/bash
# With volume mounts from SELinux enabled system
podman run -it -v $PWD:/opt/ansible:z registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest /bin/bash
```

- Run adhoc commands inside image:

```shell
podman run --rm <image-name> <command>
```

- Run ansible-builder:

```shell
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

- [Makefile Tutorial](https://makefiletutorial.com/)
- [Docker and Makefiles: Building and Pushing Images with Make](https://earthly.dev/blog/docker-and-makefiles/)
- [Ansible Builder and Execution Environments](https://ario.cloud/posts/ansible-builder-ee)
- [Docker and Makefiles](https://earthly.dev/blog/docker-and-makefiles/)
- [Best practices for building images that pass Red Hat Container Certification](https://developers.redhat.com/articles/2021/11/11/best-practices-building-images-pass-red-hat-container-certification)

## License

[GNU General Public License v3.0](LICENSE)

## Author

John Wadleigh
