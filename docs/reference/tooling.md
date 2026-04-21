---
title: Tooling Reference
---

# Tooling Reference

This document provides a reference for the key tools used in this project.

| Tool              | Purpose                                         | Example Command |
|-------------------|-------------------------------------------------|-----------------|
| ansible-builder   | Build EE images from `execution-environment.yml`| `ansible-builder build --tag my-ee:v1` |
| ansible-navigator | Run playbooks inside an EE                       | `ansible-navigator run files/playbook.yml --eei my-ee:v1` |
| podman            | Build, run, and inspect container images         | `podman inspect my-ee:v1` |
| make              | Orchestrate build/test/publish workflows         | `make build test publish` |
| llms.txt (optional) | Declare LLM crawling/usage preferences           | See CLI: https://llmstxt.org/intro.html#cli |

## ansible-builder

`ansible-builder` is a tool for building Ansible Execution Environment images.

-   **[Official Documentation](https://ansible-builder.readthedocs.io/en/latest/index.html)**
-   **[Source Code](https://github.com/ansible/ansible-builder)**

## ansible-navigator

`ansible-navigator` is a tool for running and developing Ansible content, with a focus on using execution environments.

-   **[Official Documentation](https://ansible.readthedocs.io/projects/navigator/)**
-   **[Source Code](https://github.com/ansible/ansible-navigator/)**

## Podman

Podman is a container runtime used for building and running the execution environment containers.

-   **[Official Website](https://podman.io/)**
-   **[Installation Guide](https://podman.io/getting-started/installation)**

## Skopeo

Skopeo is a command-line tool that performs various operations on container images and image repositories.

-   **[Source Code](https://github.com/containers/skopeo)**

## Buildah

Buildah is a tool that facilitates building OCI container images.

-   **[Source Code](https://github.com/containers/buildah)**
