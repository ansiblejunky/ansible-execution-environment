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
ROOT_DIR="collections_content"

# Header output
echo "Scanning for Python packages in requirements.txt files under '$ROOT_DIR'..."
echo ""

# Prepare ansible.cfg and download collections
mkdir -p ${ROOT_DIR}
ansible-galaxy collection install -r files/requirements.yml -p ${ROOT_DIR}/

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
