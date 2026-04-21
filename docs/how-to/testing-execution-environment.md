---
title: How to Test Your Execution Environment
description: Run a regression test of your EE using ansible-navigator and basic container checks.
---

# How to Test Your Execution Environment

This guide provides instructions on how to perform regression testing on your custom Ansible Execution Environment using `ansible-navigator`.

## Outcome

Validate that your EE runs playbooks, exposes expected configuration, and can be inspected interactively.

## Prerequisites

- A custom execution environment image built by this project.
- `ansible-navigator` installed on your system.

## Steps

### 1. Run a Test Playbook

You can run a playbook within your execution environment to test its functionality. The `ansible-navigator run` command launches the container, executes the playbook, and provides an interactive view of the playbook's execution.

```bash
# Replace ansible-ee:5.0 with your image name and tag
ansible-navigator run playbook.yml --container-engine podman --execution-environment-image ansible-ee:5.0
```

To exit the interactive view, use `:q!` as you would in the `vi` editor.

### 2. Check the Configuration

You can inspect the configuration of your execution environment, including the Ansible version and collections, using the `ansible-navigator config` command.

```bash
# Replace ansible-ee:5.0 with your image name and tag
ansible-navigator config --container-engine podman --execution-environment-image ansible-ee:5.0
```

Expected results:
- Ansible version and collection list match your build intent.
- No missing collections or Python dependency errors.

### 3. Inspect the Image Manually

For more in-depth testing, you can start a shell session inside the container to manually inspect its contents and run commands.

```bash
# Replace with your image name and tag
podman run -it -v $PWD:/opt/ansible <your-image-name> /bin/bash
```

Inside the container, you can:
- Verify the versions of installed packages.
- Check that Ansible collections are in the correct location.
- Manually run Python scripts or other commands to test dependencies.

## Troubleshooting
- If `ansible-navigator run` fails, try `--mode stdout` for clearer logs.
- Use `podman logs` when running containers with `--detach`.
- Run `pip check` inside the container to identify dependency conflicts.
