# Provisioning script to prepare RHEL 9 for Ansible Execution Environment development
# This script installs necessary packages, configures git, and sets up a Python virtual environment for Ansible development.
# It is intended to be run on a RHEL 9 system with access to the Red Hat subscription services.

# Assumptions:
# - system is already registered and content attached
#   https://access.redhat.com/solutions/5524661

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
    python3-pip \
    gcc gcc-c++ \
    openssl openssl-devel \
    libpq-devel glibc-headers \
    libcurl-devel libssh-devel \
    python3-devel openldap-devel

# Prepare python virtual environment for Ansible development
# This is a best practice to avoid conflicts with system Python packages.
# It allows for isolated package management and version control.
python3 -m pip install --upgrade pip
python3 -m pip install virtualenv
mkdir -p ~/venvs/
python3 -m venv ~/venvs/ansible
source ~/venvs/ansible/bin/activate && \
    pip install --upgrade pip && \
    pip install ansible-dev-tools
