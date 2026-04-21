# Technology Stack

This document provides an overview of the specific technologies and dependencies used in this project to build the default Ansible Execution Environment.

## Core Technologies

- **Ansible:** The automation engine for which the execution environments are built.
- **Python:** The underlying language for Ansible and many of the required collections and modules.
- **YAML:** The language used for Ansible playbooks and configuration files.
- **RHEL 9 UBI:** The base operating system for the container image, provided by `registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest`.

## Build and Execution Tools

- **ansible-builder:** The primary tool for building execution environment container images, configured via `execution-environment.yml`.
- **ansible-navigator:** The recommended tool for running playbooks using the built execution environments, configured via `ansible-navigator.yml`.
- **Podman:** The default container runtime used to build and run the container images.
- **Make:** Used to orchestrate the build, test, and publish processes via the `Makefile`.

## Why these choices

- AAP base images provide certified content and security updates, reducing maintenance risk.
- Podman supports rootless containers and SELinux, aligning with hardened RHEL hosts.
- `ansible-builder` encodes dependencies as code, improving reproducibility versus ad‑hoc Dockerfiles.
- `make` gives simple, discoverable workflows (`make build test publish`).

## Ansible Collection Dependencies (`files/requirements.yml`)

- `redhat_cop.aap_utilities`
- `infra.aap_configuration`
- `ansible.platform`
- `ansible.hub`
- `ansible.controller`
- `ansible.eda`
- `amazon.aws`
- `azure.azcollection`
- `community.general`
- `ansible.utils`

## Python Package Dependencies (`files/requirements.txt`)

- **ara:** A reporting tool for Ansible Playbooks.

## System-Level Dependencies (`files/bindep.txt`)

- `dnf`
- `git`
- `jq`
- `rsync`
- `unzip`
- `tar`
- `sudo`
- `libcurl-devel`
- `curl-devel`
- `openssl-devel`
- `openldap-devel`

## Tool Versions

The exact versions of the tools used will depend on your build environment. You can check the installed versions with the following commands. This project was tested with the versions listed below.

-   **ansible-builder:**
    ```bash
    ansible-builder --version
    # Tested with: ansible-builder 3.0.1
    ```
-   **ansible-navigator:**
    ```bash
    ansible-navigator --version
    # Tested with: ansible-navigator 24.1.0
    ```
-   **podman:**
    ```bash
    podman --version
    # Tested with: podman version 4.4.1
    ```
