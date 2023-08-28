whoami
sudo dnf install -y podman python3-pip git
sudo git config --global --add safe.directory /vagrant

python3 -m pip install --upgrade pip
python3 -m pip install virtualenv
python3 -m venv ansible
source ansible/bin/activate && pip install --upgrade pip && pip install ansible-navigator[ansible-core] ansible-core
