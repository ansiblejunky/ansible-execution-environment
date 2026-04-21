---
title: Build Docs Locally (MkDocs)
description: Install MkDocs, build the site, and verify it serves locally.
---

# Build Docs Locally (MkDocs)

This project uses MkDocs (Material) with the config at `mkdocs.yml/mkdocs.yml`.

Prerequisites
- Python 3.9+ and `pip` installed.

Steps
1) Create a virtual environment and install dependencies:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r mkdocs.yml/requirements.txt
   ```
2) Build the site:
   ```bash
   mkdocs build -f mkdocs.yml/mkdocs.yml
   ```
3) Serve locally on port 8000:
   ```bash
   mkdocs serve -f mkdocs.yml/mkdocs.yml -a 127.0.0.1:8000
   # open http://127.0.0.1:8000
   ```

Troubleshooting
- Command not found: ensure your virtualenv is active (`source .venv/bin/activate`).
- Missing plugin errors: verify `mkdocs.yml/requirements.txt` is installed.
- 404 on pages: confirm files exist under `docs/` and nav paths match.

Quick test script
- Run `make docs-test` to build, serve in the background, and verify the site responds at `http://127.0.0.1:8000/`. Script: `scripts/test-docs-local.sh`.

Outcome
- A built site in `site/` and a local dev server on port 8000.
