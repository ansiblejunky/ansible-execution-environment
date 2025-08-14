#!/bin/bash

# Folder to scan
ROOT_DIR="collections"

# Header
echo "Scanning for Python packages in requirements.txt files under '$ROOT_DIR'..."
echo ""

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