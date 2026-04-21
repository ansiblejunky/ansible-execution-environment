---
title: CI/CD with GitHub Actions and Tekton
description: Automate EE builds and publishes to Quay using Podman in GitHub Actions or Tekton.
---

# CI/CD with GitHub Actions and Tekton

This guide shows how to automate building and publishing the Execution Environment (EE) to Quay using GitHub Actions, and how to adapt for Tekton.

## GitHub Actions (recommended, Podman-first)

Prerequisites:
- Quay repo created (e.g., `quay.io/<org>/<repo>`).
- Secrets in your GitHub repo: `QUAY_USERNAME`, `QUAY_PASSWORD`, `ANSIBLE_HUB_TOKEN`.
- Optional (for Red Hat content): `REDHAT_REGISTRY_USERNAME`, `REDHAT_REGISTRY_PASSWORD`.

Steps:
- Edit `.github/workflows/build-and-push.yml` and set `TARGET_NAME` (e.g., `yourorg/ansible-ee-minimal`) and `TARGET_TAG`.
- Push to `main` or run via “Run workflow”. The job will:
  - Install Podman, `ansible-builder`, and `ansible-navigator`.
  - Login to `registry.redhat.io` (if credentials provided) and `quay.io` with Podman.
  - `make build` → `make test` → `make publish` using `CONTAINER_ENGINE=podman`.

Verification:
- Pull from another machine: `podman pull quay.io/<org>/<repo>:<tag>`.

Outcome:
- On push/PR, the workflow builds, tests, and publishes the image to Quay (on main).

## Tekton (OpenShift Pipelines)

Approach: generate the build context with `ansible-builder create`, then build/push with Buildah.

Example Task (inline):
```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: ee-buildah
spec:
  params:
    - name: image
    - name: tag
  workspaces:
    - name: source
  steps:
    - name: create-context
      image: quay.io/ansible/ansible-builder:latest
      workingDir: $(workspaces.source.path)
      script: |
        #!/usr/bin/env bash
        set -euxo pipefail
        ansible-builder create
    - name: build-push
      image: quay.io/buildah/stable
      securityContext:
        privileged: true
      workingDir: $(workspaces.source.path)
      env:
        - name: REGISTRY_AUTH_FILE
          value: /auth/auth.json
      volumeMounts:
        - name: registry-auth
          mountPath: /auth
      script: |
        #!/usr/bin/env bash
        set -euxo pipefail
        buildah bud -f context/Containerfile -t $(params.image):$(params.tag) context
        buildah push $(params.image):$(params.tag)
  volumes:
    - name: registry-auth
      secret:
        secretName: registry-auth
```

Notes:
- Provide a pull/push secret named `registry-auth` containing an `auth.json` for both `registry.redhat.io` and `quay.io`.
- The `build-push` step needs `privileged` SCC (cluster policy) to run Buildah.
- Use a `Pipeline` to wire this task with a `git-clone` step and parameters (image, tag).

Minimal PipelineRun example:
```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: ee-build-run
spec:
  pipelineSpec:
    workspaces:
      - name: ws
    params:
      - name: image
      - name: tag
    tasks:
      - name: clone
        taskRef:
          name: git-clone
          kind: ClusterTask
        workspaces:
          - name: output
            workspace: ws
        params:
          - name: url
            value: https://github.com/yourorg/ansible-execution-environment.git
      - name: build
        runAfter: [clone]
        taskRef:
          name: ee-buildah
        workspaces:
          - name: source
            workspace: ws
        params:
          - name: image
            value: quay.io/yourorg/ansible-ee-minimal
          - name: tag
            value: v5
```

Troubleshooting:
- Missing packages at build time → add to `files/bindep.txt`.
- Galaxy/Hub access issues → verify `ANSIBLE_HUB_TOKEN` and registry auth.
- SELinux/permissions in Tekton → ensure privileged SCC or use OpenShift Pipelines best practices.
