# Ansible Execution Environments Demo

Basic information to help you get familiar with Ansible Execution Environments and the latest Ansible Automation Platform.

General information on [Ansible Controller](https://docs.ansible.com/automation-controller/latest/html/userguide/index.html) and the related [execution environments](https://docs.ansible.com/automation-controller/latest/html/userguide/ee_reference.html).

## Prerequisites

### Images and Containers

- [https://stackoverflow.com/a/51660942](What are image layers?)
- [https://docs.docker.com/develop/develop-images/dockerfile_best-practices/](Best Practices for Writing Dockerfiles)

### Execution Environments

- [What are Red Hat Ansible Automation Platform automation execution environments?](https://www.redhat.com/en/technologies/management/ansible/automation-execution-environments)
- [Automation Controller - Execution Environments](https://docs.ansible.com/automation-controller/latest/html/userguide/execution_environments.html)

### Ansible Builder

- [Introduction to Ansible Builder](https://www.ansible.com/blog/introduction-to-ansible-builder)
- [Ansible Builder - Guide](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.1/html/ansible_builder_guide/assembly-using-builder)
- [Ansible Builder - Read The Docs](https://ansible-builder.readthedocs.io/en/latest/index.html)
- [Ansible Builder - Source Code](https://github.com/ansible/ansible-builder)

### Ansible Navigator

- [Ansible Navigator - Source Code](https://github.com/ansible/ansible-navigator/)
- [Ansible Navigator - Settings](https://github.com/ansible/ansible-navigator/blob/main/docs/settings.rst)

## Installation

Run the following steps using `pyenv`.

```shell
pyenv install 3.8.9
pyenv activate 3.8.9 ansible-ee

pip install ansible-builder
pip install ansible-navigator
```

## Build Image

Ansible playbooks will be executed from a container image.
We define our "golden" image using a YAML template file named `execution-environment.yml`.
The image is built using that template file and running the `ansible-builder` tool.

Let's first define our execution environment using the template.

```yaml
---
version: 1

build_arg_defaults:
  EE_BASE_IMAGE: 'quay.io/ansible/ansible-runner:latest'

ansible_config: 'ansible.cfg'

dependencies:
  galaxy: requirements.yml
  python: requirements.txt
  system: bindep.txt

additional_build_steps:
  prepend: |
    RUN whoami
    RUN cat /etc/os-release
    RUN pip3 install --upgrade pip setuptools
  append:
    - RUN echo This is a post-install command!
    - RUN ls -la /etc
```

Now let's run `ansible-builder` to create the image based on our template. Note that Podman is used by default to build images but we will use Docker instead. Also the default name and tag for the container image being built is `ansible-execution-env:latest` but it's highly recommended that you avoid using "latest" and set your own tag/version using the `--tag` argument.

```yaml
ansible-builder build -v 3 --container-runtime=docker --tag ansible-execution-env:1.0
```

Docker now has the `ansible-execution-env` image created with tag `1.0`:

```yaml
$ docker image list
REPOSITORY                            TAG             IMAGE ID       CREATED         SIZE
ansible-execution-env                 1.0             9fec21fe39be   2 hours ago     987MB
```

## Run the image

We use `ansible-navigator` to start a container by pulling the image we built and running Ansible playbook within it.

So let's try to run our playbook using `ansible-navigator`. Set the default container runtime using the `--container-engine docker` argument. Point the tool to the execution environment image name by using the `--execution-environment-image` argument along with the image name and tag. This is where it's important to not use "latest" as the tag so we ensure Docker knows where to grab the image.

```yaml
ansible-navigator run playbook.yml --container-engine docker --execution-environment-image ansible-execution-env:1.0
```

The tool launches the container, runs the playbook and shows an interactive screen where you can watch the playbook run through.

To quit the tool, use similar mechanism `:q!` like within a `vi` editor.

## Scan the image

Don't forget security! Use the docker command to scan the image you built to ensure it's safe to use. To use this feature you need to login to Docker Hub and Synk (see below commands).

```yaml
# Login to Docker Hub
docker login

# Login to Synk
docker scan --login

# Scan the image
docker scan ansible-execution-env:1.0
```

## Tips and Tricks

Get the version of ansible within an image

```yaml
podman run --rm registry.redhat.io/ansible-automation-platform-21/ee-supported-rhel8 ansible --version
```