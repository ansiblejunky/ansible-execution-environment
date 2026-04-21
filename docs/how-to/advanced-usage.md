---
title: Advanced Usage Guide
---

# Advanced Tasks

Task-oriented guides for power users. Each task has prerequisites, steps, verification, and rollback.

## Task: Inspect the built image

Outcome: verify contents and metadata of the EE image.

Before you start:
- Built image available (`make build`).

Steps:
- High-level summary: `make info`
- Deep metadata: `make inspect`
- Interactive debug shell: `make shell`

Verification:
- Confirm expected collections appear in `ansible-galaxy collection list` output from `make info`.

Rollback:
- `make clean` to remove artifacts; rebuild if needed.

## Task: Publish to a custom registry

Outcome: image available in your chosen registry and tag.

Before you start:
- Logged into target registry; set `TARGET_HUB`, `TARGET_NAME`.

Steps:
1) Edit `Makefile` variables, for example:
```makefile
TARGET_HUB ?= docker.io
TARGET_NAME ?= your-dockerhub-username/my-custom-ee
```
2) Authenticate: `podman login docker.io`
3) Publish: `make publish`

Verification:
- Pull the pushed tag from another host: `podman pull docker.io/your-dockerhub-username/my-custom-ee:$(TARGET_TAG)`.

Rollback:
- Delete remote tag in the registry UI or CLI; retag and republish.

## Task: Change the base image

Outcome: build the EE on a different supported base image.

Before you start:
- Decide on a supported base (e.g., AAP supported vs minimal).

Steps:
1) Edit `execution-environment.yml`:
```yaml
images:
  base_image:
    name: 'registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest'
```
2) Rebuild: `make build`

Verification:
- Run `make info` and confirm base image labels and package set.

Rollback:
- Revert the change and rebuild: `git checkout -- execution-environment.yml && make build`.
