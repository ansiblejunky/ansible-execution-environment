---
title: How to Add Windows Support
description: Enable Windows automation by adding collections, WinRM Python deps, and Kerberos packages to the EE.
---

# How to Add Windows Support

This guide provides a practical, step-by-step example of how to modify the execution environment to add support for automating Windows systems. This involves adding a new Ansible collection and its required Python and system-level dependencies.

## Prerequisites

- A successfully built base execution environment, as described in the [Getting Started tutorial](../tutorials/getting-started.md).

## Outcome

An EE image capable of connecting to Windows hosts via WinRM and authenticating with Kerberos where required.

## Step 1: Add the Windows Ansible Collection

The `community.windows` and `ansible.windows` collections contain the necessary modules for Windows automation.

1.  Open the `files/requirements.yml` file.
2.  Uncomment or add the `community.windows` and `ansible.windows` collections:

```yaml
collections:
  # ... other collections
  - name: community.windows # windows
  - name: ansible.windows # windows
```

## Step 2: Add the Python Dependency for WinRM

Windows automation with Ansible uses the Python Windows Remote Management (WinRM) protocol. The `pywinrm` library is required for this.

1.  Open the `files/requirements.txt` file.
2.  Uncomment the `pywinrm` package:

```
# (Optional) Windows automation - connectivity requirements https://docs.ansible.com/ansible/latest/user_guide/windows_winrm.html#what-is-winrm
pywinrm>=0.3.0
```

## Step 3: Add System-Level Dependencies for Kerberos

For secure authentication with Windows hosts, you will likely need Kerberos support.

1.  Open the `files/bindep.txt` file.
2.  Uncomment the Kerberos packages:

```
# (Optional) Windows Authentication - Kerberos
# https://docs.ansible.com/automation-controller/latest/html/administration/kerberos_auth.html
krb5-libs [platform:rpm]
krb5-workstation [platform:rpm]
krb5-devel [platform:rpm]
```

## Step 4: Rebuild the Execution Environment

Now that you have added the new dependencies, you must rebuild the image for the changes to take effect.

Run the build command from the root of the repository:

```bash
make build
```

Your new execution environment image will now contain the necessary components to automate Windows systems.

## Verification
- Test connectivity from the controller: `ansible -i hosts windows -m win_ping -e "ansible_connection=winrm"`.
- Confirm Kerberos libraries are present in the container if using domain auth.

## Rollback
- Revert edits in `files/requirements.yml`, `files/requirements.txt`, and `files/bindep.txt` and rebuild.
