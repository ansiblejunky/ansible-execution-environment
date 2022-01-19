# Ansible Execution Environments Demo

Basic information to help you get familiar with Ansible Execution Environments and the latest Ansible Automation Platform.

## Prerequisites

### Ansible Builder

https://www.ansible.com/blog/introduction-to-ansible-builder
https://ansible-builder.readthedocs.io/en/latest/index.html
https://github.com/ansible/ansible-builder

### Ansible Navigator

https://github.com/ansible/ansible-navigator/
https://github.com/ansible/ansible-navigator/blob/main/docs/settings.rst

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

#build_arg_defaults:
#  EE_BASE_IMAGE: 'quay.io/ansible/ansible-runner:stable-2.10-devel'

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

Now let's run `ansible-builder` to create the image based on our template. Note that Podman is used by default to build images - we will use Docker instead. Also the default name for the container image being built is `ansible-execution-env` unless you override this with the `--tag=tagname` argument.

```yaml
ansible-builder build --container-runtime=docker
```

Docker now has the `ansible-execution-env` image created:

```yaml
$ docker image list
REPOSITORY                            TAG             IMAGE ID       CREATED         SIZE
ansible-execution-env                 latest          9fec21fe39be   2 minutes ago   987MB
```

## Run the image

By default, `ansible-navigator` uses a container runtime (podman or docker, whichever it finds first) and runs Ansible within an execution environment (a pre-built container image which includes ansible-core along with a set of Ansible collections). This default behavior can be disabled by starting ansible-navigator with `--execution-environment false`. In this case, Ansible and any collections needed must be installed manually on the system.

We will now try to run a playbook using `ansible-navigator` and leverage our new execution environment image we created.

```yaml
ansible-navigator run playbook.yml --container-engine docker --execution-environment-image ansible-execution-env 
```