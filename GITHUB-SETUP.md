# 🔐 GitHub Access Setup Script

> Automated GitHub Personal Access Token (PAT) configuration for VPS servers with flexible token scoping options.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Requirements](#-requirements)
- [Quick Start](#-quick-start)
- [Usage Guide](#-usage-guide)
- [Token Scoping](#-token-scoping)
- [Security Considerations](#-security-considerations)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Overview

The `setup-github.sh` script automates GitHub access configuration on VPS servers. It allows you to:

- Configure git user identity (name and email)
- Set up GitHub Personal Access Tokens (PATs)
- Use host-wide tokens or per-repo tokens
- Update/replace tokens on subsequent runs
- Manage stored credentials

**Key Benefit**: Tokens are scoped to only what the PAT allows - the script doesn't grant additional permissions beyond what your token provides.

---

## ✨ Features

### 🔧 Git Identity Configuration
- ✅ Set global `user.name` and `user.email`
- ✅ View current configuration
- ✅ Update configuration anytime

### 🔑 Token Management
- ✅ **Host-wide tokens**: One token for all GitHub repositories
- ✅ **Per-repo tokens**: Token scoped to specific repository (recommended)
- ✅ **Token replacement**: Update tokens without manual file editing
- ✅ **Credential listing**: View stored credentials (tokens masked)
- ✅ **Credential removal**: Remove credentials by username

### 🛡️ Security Features
- ✅ Token masking in output
- ✅ Secure file permissions (`~/.git-credentials` set to 600)
- ✅ Per-repo scoping for minimal access
- ✅ Clear warnings about plaintext storage

---

## 📋 Requirements

| Requirement | Description |
|------------|-------------|
| **OS** | Linux (Ubuntu/Debian recommended) |
| **Tools** | Git (script can install if missing) |
| **Access** | GitHub Personal Access Token |
| **Permissions** | User-level access (no sudo required for most operations) |

---

## 🚀 Quick Start

### On Your VPS Server

```bash
# Clone the repository
git clone <repository-url> /tmp/autoscripts
cd /tmp/autoscripts

# Run the setup script
./setup-github.sh
```

### First-Time Setup

1. **Configure Git Identity** (Option 1)
   - Enter your name (e.g., "John Doe")
   - Enter your email (e.g., "you@example.com")

2. **Add GitHub Token** (Option 2)
   - Choose token scope (host-wide or per-repo)
   - Enter GitHub username
   - Enter Personal Access Token
   - For per-repo: Enter repository URL

3. **Verify** (Option 3)
   - List stored credentials to verify setup

---

## 💻 Usage Guide

### Main Menu Options

```
==========================================
 GitHub Setup & Token Manager
==========================================
 1) Configure git username/email
 2) Add/Update GitHub token
 3) List stored GitHub credentials
 4) Remove GitHub credentials by username
 5) Exit
==========================================
```

### Option 1: Configure Git Identity

Sets your global git `user.name` and `user.email`. These are used for all git commits.

**Example:**
```
Enter git user.name  (e.g., John Doe): John Doe
Enter git user.email (e.g., you@example.com): john@example.com
```

### Option 2: Add/Update GitHub Token

**Token Scoping Options:**

#### Option 2.1: Host-Wide Token
- One token for all GitHub repositories
- Use when you need access to multiple repos
- Token permissions apply to all repos you access

#### Option 2.2: Per-Repo Token (Recommended)
- Token scoped to a specific repository
- Better security isolation
- Use different tokens for different projects
- Example URL: `https://github.com/owner/repo.git`

**Example Flow:**
```
Choose option (1/2): 2
Enter GitHub repo URL to scope this token to: https://github.com/myorg/myproject.git
Enter your GitHub username (for URL): myusername
Enter GitHub Personal Access Token: ghp_xxxxxxxxxxxx
```

### Option 3: List Stored Credentials

View all stored GitHub credentials with tokens masked for security.

**Example Output:**
```
[INFO]  Stored GitHub credentials (token masked):
https://myusername:***@github.com/myorg/myproject
```

### Option 4: Remove GitHub Credentials

Remove credentials for a specific GitHub username.

**Example:**
```
Enter GitHub username whose credentials you want to remove: myusername
[OK]    Removed credentials for user 'myusername' on github.com.
```

---

## 🔒 Token Scoping

### Understanding Token Scope

The script stores tokens in `~/.git-credentials` using git's credential helper. The scope determines which repositories can use the token:

| Scope Type | URL Format | Use Case |
|-----------|------------|----------|
| **Host-wide** | `https://username:token@github.com` | Multiple repos, same access level |
| **Per-repo** | `https://username:token@github.com/owner/repo` | Single project, isolated access |

### How Git Uses Tokens

When you clone/pull/push:

1. Git checks `~/.git-credentials` for matching URLs
2. If a per-repo token exists for that specific repo, it uses that
3. Otherwise, it falls back to host-wide token (if configured)
4. Token permissions are enforced by GitHub, not by this script

### Token Permissions

**Important**: This script only stores the token. GitHub enforces the token's actual permissions:

- ✅ Token can only access what you granted in GitHub settings
- ✅ Script cannot expand token permissions
- ✅ Use minimal scopes when creating PATs in GitHub

**Recommended PAT Scopes:**
- `repo` - Full repository access (if needed)
- `read:packages` - Read packages (if using GitHub Packages)
- `write:packages` - Write packages (if publishing)

---

## 🔐 Security Considerations

### ⚠️ Important Security Notes

1. **Plaintext Storage**
   - Tokens are stored in `~/.git-credentials` in plaintext
   - File permissions are set to `600` (owner read/write only)
   - Consider using SSH keys for production environments

2. **Token Scope**
   - Use per-repo tokens when possible (Option 2)
   - Create tokens with minimal required permissions
   - Regularly rotate tokens

3. **File Location**
   - Credentials stored in: `~/.git-credentials`
   - Backup this file securely if needed
   - Never commit this file to git repositories

4. **Token Permissions**
   - The script doesn't grant permissions - GitHub does
   - Token scope is determined when you create the PAT in GitHub
   - Script only stores what you provide

### Best Practices

✅ **Do:**
- Use per-repo tokens for different projects
- Create tokens with minimal scopes
- Regularly review and rotate tokens
- Use different tokens for different environments

❌ **Don't:**
- Share tokens between team members
- Commit `~/.git-credentials` to repositories
- Use overly broad token scopes
- Store tokens in unencrypted backups

---

## 🔧 Troubleshooting

### Git Not Installed

**Error:** `git: command not found`

**Solution:**
```bash
# On Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y git

# Then run the script again
./setup-github.sh
```

### Token Not Working

**Symptoms:** Git operations fail with authentication errors

**Solutions:**
1. Verify token is valid in GitHub Settings → Developer settings → Personal access tokens
2. Check token hasn't expired
3. Verify token has correct permissions for the repository
4. Re-run script and update token (Option 2)

### Wrong Token Used for Repo

**Symptoms:** Using host-wide token instead of per-repo token

**Solution:**
- Per-repo tokens take precedence
- Check stored credentials (Option 3)
- Remove host-wide token if conflicting (Option 4)
- Re-add per-repo token (Option 2)

### Credentials File Not Found

**Error:** `No ~/.git-credentials file found`

**Solution:**
- This is normal if you haven't added any tokens yet
- Run Option 2 to add your first token
- File will be created automatically

### Permission Denied

**Error:** `Permission denied` when accessing `~/.git-credentials`

**Solution:**
```bash
# Fix file permissions
chmod 600 ~/.git-credentials

# Verify ownership
ls -la ~/.git-credentials
```

---

## 📝 Example Workflows

### Workflow 1: Single Project Setup

```bash
./setup-github.sh
# Choose 1: Set name/email
# Choose 2: Add per-repo token for specific project
# Done!
```

### Workflow 2: Multiple Projects, Different Tokens

```bash
./setup-github.sh
# Choose 1: Set name/email
# Choose 2: Add token for project A
# Run script again
# Choose 2: Add token for project B (different token)
# Each project uses its own token
```

### Workflow 3: Update Expired Token

```bash
./setup-github.sh
# Choose 2: Add/Update token (enters same username/repo)
# Old token is automatically replaced
```

### Workflow 4: Switch from Host-Wide to Per-Repo

```bash
./setup-github.sh
# Choose 4: Remove host-wide token
# Choose 2: Add per-repo token
```

---

## 📚 Related Files

- **Main README**: See [README.md](README.md) for other scripts
- **Credential Storage**: `~/.git-credentials` (created automatically)
- **Git Config**: `~/.gitconfig` (modified by script)

---

## 🔗 Useful Commands

```bash
# View git configuration
git config --global --list

# View stored credentials (manual)
cat ~/.git-credentials

# Test GitHub access
git ls-remote https://github.com/owner/repo.git

# Remove all credentials (manual)
rm ~/.git-credentials
```

---

## 📝 License

This script is provided as-is for automation purposes. Use at your own risk.

---

<div align="center">

**Made with ❤️ for VPS automation**

</div>

