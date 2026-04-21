# Security Checklist

This document outlines security practices for the ansible-execution-environment repository.

## ⚠️ NEVER Commit These Files

### Secrets and Credentials
- ❌ `files/optional-configs/rhsm-activation.env` (RH_ORG, RH_ACT_KEY)
- ❌ `files/optional-configs/oc-install.env` (if contains sensitive URLs)
- ❌ `token` or any file containing ANSIBLE_HUB_TOKEN
- ❌ Any file with passwords, API keys, or authentication tokens
- ❌ SSH private keys
- ❌ TLS/SSL private keys or certificates

### Environment Files
- ❌ `.env` files with credentials
- ❌ `*.pem` files (SSL certificates)
- ❌ `*.key` files (private keys)
- ❌ `secrets.yml` or similar credential stores

### Registry Credentials
- ❌ Quay.io credentials
- ❌ Red Hat Registry credentials
- ❌ Docker Hub credentials
- ❌ Any `~/.docker/config.json` or similar

## ✅ Protected by .gitignore

The following patterns are already in `.gitignore`:

```gitignore
# Secrets and credentials
files/optional-configs/rhsm-activation.env
files/optional-configs/oc-install.env
token
*.env
*.pem
*.key
secrets.yml

# Build artifacts
context/
*.tar
*.tar.gz
```

## 🔍 Pre-Commit Security Checks

Before EVERY commit, verify:

### 1. Check Git Status
```bash
git status
```
Look for any files in `files/optional-configs/` or files ending in `.env`, `.pem`, `.key`

### 2. Review Staged Changes
```bash
git diff --cached
```
Search for:
- Passwords or tokens in plain text
- API keys or secret keys
- RH_ORG or RH_ACT_KEY values
- ANSIBLE_HUB_TOKEN values
- Quay.io credentials

### 3. Grep for Common Secret Patterns
```bash
# Check for potential secrets in staged files
git diff --cached | grep -i -E '(password|token|secret|key|api_key|auth)'

# Check for specific credential patterns
git diff --cached | grep -E '(RH_ORG|RH_ACT_KEY|ANSIBLE_HUB_TOKEN|QUAY_)'
```

### 4. Verify .gitignore Coverage
```bash
# Test if sensitive files would be ignored
git check-ignore files/optional-configs/rhsm-activation.env
git check-ignore files/optional-configs/oc-install.env
git check-ignore token
```
All should return the filename (meaning they're ignored)

## 🚨 If You Accidentally Commit Secrets

### Immediate Actions

1. **DO NOT PUSH** if you haven't pushed yet
2. Reset the commit:
   ```bash
   git reset --soft HEAD~1
   git restore --staged <file-with-secret>
   ```

3. **If already pushed to GitHub**:
   - Immediately rotate/revoke the exposed credentials
   - Contact Red Hat security if RH credentials exposed
   - Revoke GitHub tokens if exposed
   - Delete and recreate Quay.io credentials
   - Consider using `git-filter-repo` to remove from history (consult Git docs)

### Recovery Commands

```bash
# If you committed but didn't push
git reset --soft HEAD~1

# If you need to remove file from staging
git restore --staged <filename>

# Verify file is ignored
git check-ignore -v <filename>
```

## 📝 Safe Documentation Practices

### In Documentation Files

✅ **DO** use examples like:
```bash
RH_ORG=your_org_id_here
RH_ACT_KEY=your_activation_key_here
OC_VERSION=stable-4.21
```

❌ **DON'T** use real values:
```bash
RH_ORG=1234567  # Real org ID
RH_ACT_KEY=abc123xyz  # Real activation key
```

### In Code Comments

✅ **DO**:
```yaml
# Set your credentials in files/optional-configs/rhsm-activation.env
# Example: RH_ORG=your_org_id
```

❌ **DON'T**:
```yaml
# RH_ORG=1234567  # My actual org ID
```

## 🔐 CI/CD Security

### GitHub Actions Secrets

Secrets should be stored in GitHub Settings → Secrets and variables → Actions:

- `ANSIBLE_HUB_TOKEN` - Red Hat Automation Hub token
- `RH_ORG` - Red Hat organization ID (optional)
- `RH_ACT_KEY` - Red Hat activation key (optional)
- `QUAY_USERNAME` - Quay.io username
- `QUAY_PASSWORD` - Quay.io password
- `REDHAT_REGISTRY_USERNAME` - Red Hat registry username
- `REDHAT_REGISTRY_PASSWORD` - Red Hat registry password

### Workflow Security

Workflows access secrets via `${{ secrets.SECRET_NAME }}` and should:
- Never echo secrets to logs
- Never write secrets to files that get committed
- Only use secrets in secure environment variables
- Check for secret availability before using

## 📋 Release Security Checklist

Before tagging ANY release:

- [ ] Run `git status` - no uncommitted sensitive files
- [ ] Run `git diff --cached` - no secrets in staged changes
- [ ] Grep for credential patterns in diff
- [ ] Verify `.gitignore` is protecting sensitive files
- [ ] Check `files/optional-configs/` is not in git
- [ ] Review all documentation for hardcoded credentials
- [ ] Verify CI/CD uses GitHub Secrets, not hardcoded values
- [ ] Confirm no `token` file is committed
- [ ] Check no `.env` files with credentials are staged

## 🛡️ GitHub Security Features

Enable these repository settings:

### Secret Scanning
- ✅ Enable secret scanning (Settings → Code security and analysis)
- ✅ Enable push protection to block secret pushes
- ✅ Review secret scanning alerts regularly

### Dependabot Security
- ✅ Enable Dependabot security updates
- ✅ Review security advisories weekly

## 📞 Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** open a public GitHub issue
2. Report to: takinosh@redhat.com
3. Include: description, impact, steps to reproduce
4. Allow time for fix before public disclosure

## References

- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [git-secrets Tool](https://github.com/awslabs/git-secrets)
- [.gitignore Documentation](https://git-scm.com/docs/gitignore)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
