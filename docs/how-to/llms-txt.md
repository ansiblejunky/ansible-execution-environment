---
title: Optional llms.txt Manifest
description: Declare LLM crawling preferences with an llms.txt file at the repo root.
---

# Optional llms.txt Manifest

Use an `llms.txt` file to declare how Large Language Models may crawl and use content from this repository.

When to use
- You want to signal allow/deny preferences for LLM ingestion of documentation and code.
- You publish this repo publicly and want a clear policy document in the root.

Steps
1) Use the ready-made policy in this repo (recommended)
   - This repository includes a curated `llms.txt` at the project root with:
     - allow: all content by default
     - disallow: secrets and build artifacts (e.g., `/token`, `/files/optional-configs/`, `/context/`, `/collections/`, `/site/`, `/.venv-docs/`, `/.git/`)
     - priority: key files agents should prefer (README, Makefile, execution-environment.yml, docs/)

Alternative: generate your own policy via CLI
- Install the CLI: https://llmstxt.org/intro.html (e.g., `pip install llms-txt`)
- Decide allow/deny/priority paths; write to `llms.txt` at the repo root.

2) Download `llms.txt` to share with an agent
   - If you’re browsing on GitHub, click the raw view and save as `llms.txt`.
   - Or, from a terminal (replace with your repo/branch if needed):
     ```bash
     curl -fsSL -o llms.txt \
       https://raw.githubusercontent.com/tosin2013/ansible-execution-environment/main/llms.txt
     ```

3) Pass the file to your agent/tooling
   - Many tools accept a `--llms-txt` or similar flag; otherwise, upload the file alongside your prompt.
   - Tell the agent to follow the priority and disallow sections.

4) Optional: Customize
   - If your fork adds sensitive paths, add them under `disallow:`.
   - If you want agents to prioritize new docs or key configs, add them under `priority:`.

Included policy highlights
- Allow: repository content by default.
- Disallow: secrets (`/token`, `/files/optional-configs/`), build outputs (`/context/`, `/collections/`, `/site/`), VCS internals (`/.git/`).
- Priority: `/README.md`, `/AGENTS.md`, `/execution-environment.yml`, `/Makefile`, `/ansible-navigator.yml`, `/docs/`.

CI tip
- Add a lightweight check to ensure `llms.txt` exists and is non-empty on PRs touching `docs/` or `README.md`.
- Optionally validate that `disallow:` includes sensitive paths (e.g., `/files/optional-configs/`).

Outcome
- A documented `llms.txt` policy at the repo root, a one-liner to download it, and optional CI guardrails.
