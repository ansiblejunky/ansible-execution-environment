#!/bin/bash
# NAME:
#   02-test.sh
# PURPOSE:
#   Scan Ansible Collections for requirements.txt files and list Python packages
# USAGE:
#   ./02-test.sh
# SOURCE:
#   https://github.com/ansiblejunky/ansible-project-template/blob/main/02-test.sh

# Folder to scan
ROOT_DIR="tmp_collections"

# Header output
echo "Scanning for Python packages in requirements.txt files under '$ROOT_DIR'..."
echo ""

# Ensure the temporary directory is clean
rm -rf ${ROOT_DIR}

# Require ANSIBLE_EE_TARGET_NAME to be set (target folder containing requirements.yml)
if [ -z "${ANSIBLE_EE_TARGET_NAME}" ]; then
    echo "Environment variable ANSIBLE_EE_TARGET_NAME must be set to the target folder containing requirements.yml"
    echo "Example: export ANSIBLE_EE_TARGET_NAME=path/to/collection_dir"
    exit 1
fi

# Install collections
mkdir -p ${ROOT_DIR}
echo "Using ANSIBLE_EE_TARGET_NAME='${ANSIBLE_EE_TARGET_NAME}'"
ansible-galaxy collection install -r ${ANSIBLE_EE_TARGET_NAME}/requirements.yml -p ${ROOT_DIR}/

# Find all requirements.txt files and process them
find "$ROOT_DIR" -type f -name "requirements.txt" | while read -r req_file; do
    echo "📄 $req_file"
    # Read and print valid lines (non-comment, non-empty)
    awk '
        /^[[:space:]]*#/ { next }     # skip comments
        /^[[:space:]]*$/ { next }     # skip empty lines
        { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print "  - " $0 }
    ' "$req_file"
    echo ""
done

# Cleanup
rm -rf collection
echo "Scanning completed."
