#!/bin/bash
# NAME:
#   provision.sh
# PURPOSE:
#   Provision RHEL 9 system for Ansible Execution Environment development
# USAGE:
#   ./provision.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/provision.sh
# REFERENCES:
#   This system is registered with an entitlement server, but is not receiving updates.
#   https://access.redhat.com/solutions/5524661

# Set versions to match EE base image
PYTHON_VERSION=3.12
ANSIBLE_VERSION=2.17.14

# Display current user
whoami

# Enable RHEL linger
sudo loginctl enable-linger $(whoami)

# Install development tools and utilities (includes make)
sudo dnf group install -y "Development Tools"
# Install required packages
sudo dnf install -y podman gettext rsync unzip tar jq git vi vim
# Install additional optional packages
sudo dnf install -y \
    skopeo \
    gcc gcc-c++ \
    openssl openssl-devel \
    libpq-devel glibc-headers \
    libcurl-devel libssh-devel \
    openldap-devel

# Install python 3.12 and its development tools
sudo dnf install -y \
      python$PYTHON_VERSION-devel \
      python$PYTHON_VERSION-pip \
      python$PYTHON_VERSION-setuptools \
      python$PYTHON_VERSION

# Prepare python virtual environment for Ansible development
# This is a best practice to avoid conflicts with system Python packages.
# It allows for isolated package management and version control.
python$PYTHON_VERSION -m pip install --upgrade pip
python$PYTHON_VERSION -m pip install virtualenv
mkdir -p ~/venvs/
python$PYTHON_VERSION -m venv ~/venvs/ansible
source ~/venvs/ansible/bin/activate && \
    pip install --upgrade pip && \
    pip install ansible-dev-tools && \
    pip install ansible-core==$ANSIBLE_VERSION
