# Ansible Execution Environments Demo

Basic information to help you get familiar with Ansible Execution Environments and the latest Ansible Automation Platform.

General information on [Ansible Controller](https://docs.ansible.com/automation-controller/latest/html/userguide/index.html) and the related [execution environments](https://docs.ansible.com/automation-controller/latest/html/userguide/ee_reference.html).

## Pipelines

OpenShift pipeline:

[How to Build Ansible Execution Environments with OpenShift Pipelines](https://cloud.redhat.com/blog/how-to-build-ansible-execution-environments-with-openshift-pipelines)

## Installation

Run the following steps using `pyenv`.

```bash
pyenv install 3.10.2
pyenv activate 3.10.2 ansible

pip install ansible-builder
pip install ansible-navigator
```

## Login

Ensure you login to the registry of choice using podman/docker command `podman login <registry_url>`

Automation Hub Registry:


Quay Registry:

- Ensure you authorize docker/podman with this registry
- Go to https://quay.io/ and login or create an account
- Navigate to top-right for Account Settings
- Select the tool icon on the left
- Set the Docker/Podman CLI Password to enable encrypted passwords
- Generate the encryped password (re-enter the password)
- Select the option "Docker Login" or "Podman Login" to get the CLI command
- Run the CLI login command to have docker/podman authorized to pull/push images
- Set the EE_BASE_IMAGE and EE_BUILDER_IMAGE in the `execution_environment.yml`

Red Hat Registry:

- Ensure you perform `docker login` command to authorize with this registry. Go to
- Go to https://access.redhat.com/terms-based-registry/
- Create registry service account (if not already created)
- Drill down on existing service account
- Select "Docker Login" tab and copy login command and run it locally to authenticate
- Troubleshooting Authentication Issues with registry.redhat.io
  https://access.redhat.com/articles/3560571
- Find existing container images using https://catalog.redhat.com/software/containers/search
- `minimal` base images contain only ansible-core
- `supported` base images contain ansible-core and automation content collections supported by Red Hat

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
envsubst < ansible-builder/ansible.cfg.template > ansible-builder/ansible.cfg

# Test tokens
mkdir collections
ansible-galaxy collection download -r ansible-builder/requirements.yml -p collections/
rm -rf collections

# Build the image
ansible-builder build --verbosity 3 --container-runtime=docker --tag ansible-ee:5.0
```

Docker now has the `ansible-ee` image created with tag `5.0`:

```yaml
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

We use `ansible-navigator` to start a container by pulling the image we built and running Ansible playbook within it.

So let's try to run our playbook using `ansible-navigator`. Set the default container runtime using the `--container-engine docker` argument. Point the tool to the execution environment image name by using the `--execution-environment-image` argument along with the image name and tag. This is where it's important to not use "latest" as the tag so we ensure Docker knows where to grab the image.

```yaml
ansible-navigator run playbook.yml --container-engine docker --execution-environment-image ansible-ee:5.0
```

The tool launches the container, runs the playbook and shows an interactive screen where you can watch the playbook run through.

To quit the tool, use similar mechanism `:q!` like within a `vi` editor.

## Push the Image

Once you have built the image locally, tested it, and scanned it for security issues - you are now ready to push the image to a registry of choice. Here we show how to push to Quay.

First, navigate to `quay.io` and under your profile create a new repository.

Then, use the following commands to tag your image and push it to Quay.

```bash
# Tag the image properly to prepare for Quay
docker tag azure-ee:5.0 quay.io/jwadleig/azure-ee:5.0
# Login to Quay
docker login quay.io
# Push image to Quay
docker push quay.io/jwadleig/azure-ee:5.0
```

## Migration of Virtual Environments

Leverage the following utils to help migrate pre-existing python virtual environments to execution environments.

[Redhat Communities of Practice Execution Environment Utilities Collection](https://github.com/redhat-cop/ee_utilities)

## Tips and Tricks

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

Run adhoc commands inside image:

```yaml
podman run --rm <image-name> <command>
```

Change the yum repositories and pip repository within the base and builder images:

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

## References

Warnings:

- [microdnf showing ibrhsm-WARNING ** and Found 0 entitlement certificates](https://access.redhat.com/solutions/4643601)

Best Practices:

- [Best Practices for successful DevSecOps](https://developers.redhat.com/articles/2022/06/15/best-practices-successful-devsecops)

Images and Containers:

- [What are image layers?](https://stackoverflow.com/a/51660942)
- [Best Practices for Writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

Execution Environments:

- [What are Red Hat Ansible Automation Platform automation execution environments?](https://www.redhat.com/en/technologies/management/ansible/automation-execution-environments)
- [Automation Controller - Execution Environments](https://docs.ansible.com/automation-controller/latest/html/userguide/execution_environments.html)
- [Execution Environment Setup Reference](https://docs.ansible.com/automation-controller/latest/html/userguide/ee_reference.html#execution-environment-setup-reference)

Podman:

- [How to set debug logging from podman?](https://access.redhat.com/solutions/3947441)
- Debugging: `podman pull --log-level debug <image>`

Ansible Builder:

- [Introduction to Ansible Builder](https://www.ansible.com/blog/introduction-to-ansible-builder)
- [Ansible Builder - Guide](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.1/html/ansible_builder_guide/assembly-using-builder)
- [Ansible Builder - Read The Docs](https://ansible-builder.readthedocs.io/en/latest/index.html)
- [Ansible Builder - Source Code](https://github.com/ansible/ansible-builder)

Ansible Navigator:

- [Ansible Navigator Creator Guide](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.0-ea/html-single/ansible_navigator_creator_guide/index)
- [Introduction to Ansible Runner](https://ansible-runner.readthedocs.io/en/stable/intro/)
- [Ansible Navigator - Source Code](https://github.com/ansible/ansible-navigator/)
- [Ansible Navigator - Settings](https://github.com/ansible/ansible-navigator/blob/main/docs/settings.rst)

