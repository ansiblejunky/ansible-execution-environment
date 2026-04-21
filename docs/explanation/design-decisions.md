# Design Decisions

This document outlines the key design decisions made in this project for building Ansible Execution Environments.

## Build Orchestration

### Why Makefile?

We chose a `Makefile` to orchestrate the build process for several reasons:

-   **Simplicity:** It provides a simple, well-understood way to define and run common tasks like `build`, `test`, `clean`, and `publish`.
-   **Standardization:** `make` is a standard tool available on most Linux and macOS systems, making it easy for others to use the project without learning a new scripting language.
-   **Declarative:** The declarative nature of Makefiles makes it easy to see the available commands and their dependencies.

## Containerization

### Why Podman?

The documentation and scripts in this repository primarily use `podman` for container management.

-   **Daemonless:** Podman runs without a central daemon, which can be a security advantage.
-   **Rootless:** It can be run by non-root users, further enhancing security.
-   **Docker Compatibility:** Podman's command-line interface is compatible with Docker's, making it easy to switch between the two.

## Dependency Management Structure

### Separation of Dependencies

The decision to use three separate dependency files (`requirements.yml`, `requirements.txt`, `bindep.txt`) aligns with the structure expected by `ansible-builder`.

-   **Clarity:** It provides a clear separation of concerns between Ansible collections, Python packages, and system-level binaries.
-   **`ansible-builder` Integration:** This structure is the standard way to define dependencies for `ansible-builder`, ensuring seamless integration with the tool.