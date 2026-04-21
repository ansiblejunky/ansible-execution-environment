---
title: Execution Environment Concepts
---

# Execution Environment Concepts

This document explains the key concepts and components related to Ansible Execution Environments.

## What is an Execution Environment?

An Ansible Execution Environment is a container image that provides a consistent and portable environment for running Ansible Playbooks. It packages a specific version of Ansible, Python, Ansible collections, and all their dependencies into a single, self-contained image.

This approach solves the problem of managing dependencies on control nodes and ensures that automations run reliably across different environments.

## Why it matters

EEs trade a slightly larger image size for reliability and repeatability. By pinning collections, Python packages, and system libs into a container, teams avoid “works on my machine” drift, pass CI consistently, and simplify promotion across dev→stage→prod. Use an EE when playbooks must be reproducible and portable; prefer lightweight virtualenvs only for local prototyping.

## Key Components

### ansible-builder

`ansible-builder` is a command-line tool that automates the process of building execution environment images. It uses a definition file (`execution-environment.yml`) to specify the base image, Ansible collections, Python requirements, and system-level dependencies.

### ansible-navigator

`ansible-navigator` is a command-line tool and text-based user interface (TUI) for running and developing Ansible content. It can use execution environments to run playbooks, ensuring that the automation is executed in the intended environment.

### Container Runtime

This repository standardizes on `podman` to build and run execution environment containers. `ansible-builder` and `ansible-navigator` will use Podman via `CONTAINER_ENGINE=podman` (default).

## Dependency Management

Execution environments have a structured way of managing dependencies:

-   **`requirements.yml`**: Defines the Ansible collections to be installed.
-   **`requirements.txt`**: Specifies the Python packages required by the collections or your custom content.
-   **`bindep.txt`**: Lists system-level dependencies that need to be installed in the container.

## Customizing the Build Process

Beyond managing dependencies, you can inject custom commands into the build process using the `additional_build_steps` directive in `execution-environment.yml`. This allows for advanced customization of the final image.

The build process is divided into several stages where you can prepend or append commands:

-   `prepend_base`: Commands run at the beginning of the build, before Ansible is installed. Useful for adding yum repositories or performing initial setup.
-   `prepend_galaxy`: Commands run before `ansible-galaxy` installs the specified collections.
-   `append_final`: Commands run at the very end of the build process. Useful for cleanup tasks or final checks.

### Example: Installing the Azure CLI

The `execution-environment.yml` file contains a commented-out example for installing the Azure CLI. To enable this, you would uncomment the following lines in the `prepend_base` section:

```yaml
additional_build_steps:
  prepend_base:
    # ... other commands
    - >
      RUN $PKGMGR install -y dnf &&
      rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
      dnf -y install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm &&
      $PKGMGR -y install azure-cli
```

This demonstrates how you can run any arbitrary `RUN` command to install software or modify the image as needed.
