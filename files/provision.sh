# Assuming system is already registered and content attached
# https://access.redhat.com/solutions/5524661
# subscription-manager register
# subscription-manager attach --auto

whoami

# Install required packages
sudo dnf install -y podman skopeo \
    python3-pip vi git jq \
    rsync unzip tar sudo \
    gcc gcc-c++ \
    openssl openssl-devel \
    libpq-devel glibc-headers \
    libcurl-devel libssh-devel \
    python3-devel openldap-devel

# Prepare python virtual environment
python3 -m pip install --upgrade pip
python3 -m pip install virtualenv
python3 -m venv ansible
source ansible/bin/activate && \
    pip install --upgrade pip && \
    pip install ansible-navigator[ansible-core] ansible-core envsubst
