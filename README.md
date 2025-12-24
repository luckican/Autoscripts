# 🚀 Autoscripts

> A collection of automation scripts for server management and deployment.

---

## 📋 Table of Contents

- [Scripts](#-scripts)
  - [install-nginx.sh](#install-nginxsh)
  - [setup-github.sh](#setup-githubsh)

---

## 📦 Scripts

### `setup-github.sh`

**GitHub Personal Access Token (PAT) configuration script** for VPS servers with flexible token scoping options.

**Platform Support:** Linux (Ubuntu/Debian)  
**Documentation:** See [GITHUB-SETUP.md](GITHUB-SETUP.md) for complete documentation

**Quick Overview:**
- Configure git user identity (name/email)
- Set up GitHub Personal Access Tokens
- Support for host-wide or per-repo token scoping
- Update/replace tokens on subsequent runs
- Manage stored credentials

**Quick Start:**
```bash
./setup-github.sh
```

---

### `install-nginx.sh`

**Automated nginx installation script for Ubuntu-based servers** with security hardening and interactive configuration options following 2024 best practices.

**Platform Support:** Ubuntu | Debian  
**License:** Use at your own risk

---

### ✨ Features

#### 🔍 Pre-installation Checks
- ✅ Verifies root privileges
- ✅ Detects Ubuntu/Debian OS
- ✅ Checks for existing nginx installation
- ✅ Displays system information (CPU, memory, disk)

#### 🛠️ System Preparation
- ✅ Updates package lists
- ✅ Upgrades existing packages
- ✅ Installs required dependencies

#### 🔒 Security Hardening
- ✅ Disables server tokens (hides nginx version)
- ✅ Adds security headers:
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `X-XSS-Protection: 1; mode=block`
  - `Referrer-Policy: strict-origin-when-cross-origin`
- ✅ Sets request size limits
- ✅ Configures rate limiting

#### ⚡ Performance Optimization
- ✅ Sets worker processes to `auto` (matches CPU cores)
- ✅ Enables gzip compression
- ✅ Optimizes worker connections

#### 🌐 Interactive Site Setup
- ✅ Prompts for domain name
- ✅ Creates site configuration
- ✅ Sets up document root
- ✅ **Automatically configures Let's Encrypt SSL certificates**

#### 📊 Post-installation
- ✅ Displays nginx status and version
- ✅ Shows active sites
- ✅ Provides useful commands
- ✅ Logs all actions to `/var/log/nginx-install.log`

---

### 📋 Requirements

| Requirement | Description |
|------------|-------------|
| **OS** | Ubuntu or Debian-based Linux distribution |
| **Privileges** | Root or sudo access |
| **Network** | Internet connection for package downloads |
| **Tools** | Git (for cloning the repository) |

---

### 🚀 Quick Start

#### Option 1: Git Clone (Recommended)

```bash
# Clone the repository
git clone <repository-url> /tmp/autoscripts
cd /tmp/autoscripts

# Run the installation script
sudo ./install-nginx.sh
```

**Or clone to a permanent location:**
```bash
git clone <repository-url> ~/autoscripts
cd ~/autoscripts
sudo ./install-nginx.sh
```

> **📝 Note:** Replace `<repository-url>` with your actual git repository URL  
> Example: `https://github.com/username/autoscripts.git`  
> Or: `git@github.com:username/autoscripts.git`

#### Option 2: Manual Copy

```bash
# 1. Copy script to server
scp install-nginx.sh user@your-server:/tmp/

# 2. SSH into server
ssh user@your-server

# 3. Make executable and run
chmod +x /tmp/install-nginx.sh
sudo /tmp/install-nginx.sh
```

---

### 💻 Usage

#### Interactive Prompts

The script will ask you:

1. **Firewall Configuration**
   ```
   Do you want to configure firewall rules? (Allow HTTP/HTTPS) (y/n):
   ```

2. **Site Setup**
   ```
   Do you want to set up a website? (y/n):
   ```

3. **Domain Name** (if site setup is yes)
   ```
   Enter domain name (e.g., example.com):
   ```

4. **Document Root** (optional)
   ```
   Enter document root path (default: /var/www/domain.com):
   ```

---

### 🔄 What the Script Does

The installation process follows these steps:

```
┌─────────────────────────────────────────────────┐
│  1. Pre-installation Checks                    │
│     • Verify root privileges                   │
│     • Detect OS                                │
│     • Check existing nginx                     │
│     • Display system info                      │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  2. System Preparation                          │
│     • Update package lists                     │
│     • Upgrade packages                         │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  3. Nginx Installation                          │
│     • Install from repositories                │
│     • Verify installation                      │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  4. Firewall Configuration (Interactive)        │
│     • Configure UFW for HTTP/HTTPS             │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  5. Security Hardening                          │
│     • Disable server tokens                    │
│     • Add security headers                     │
│     • Configure rate limiting                  │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  6. Performance Optimization                    │
│     • Set worker processes                     │
│     • Enable gzip compression                  │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  7. Service Management                          │
│     • Start nginx                              │
│     • Enable on boot                           │
│     • Test configuration                       │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  8. Site Configuration (Interactive)            │
│     • Create site config                       │
│     • Set up SSL certificate                   │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  9. Post-installation Summary                  │
│     • Display status and info                  │
└─────────────────────────────────────────────────┘
```

---

### 📁 Configuration Files

The script creates and modifies the following files:

| File | Description |
|------|-------------|
| `/etc/nginx/nginx.conf` | Main nginx configuration (modified) |
| `/etc/nginx/conf.d/security-headers.conf` | Security headers configuration |
| `/etc/nginx/conf.d/rate-limit.conf` | Rate limiting configuration |
| `/etc/nginx/sites-available/domain.com` | Site configuration (if site setup chosen) |
| `/etc/nginx/sites-enabled/domain.com` | Enabled site symlink |
| `/var/log/nginx-install.log` | Installation log file |

> **💡 Tip:** Configuration backups are automatically created before modifications

---

### 🛠️ Useful Commands

#### Service Management

```bash
# Check nginx status
systemctl status nginx

# Test nginx configuration
nginx -t

# Reload nginx (after config changes)
systemctl reload nginx

# Restart nginx
systemctl restart nginx
```

#### Log Monitoring

```bash
# View error log (real-time)
tail -f /var/log/nginx/error.log

# View access log (real-time)
tail -f /var/log/nginx/access.log

# View installation log
cat /var/log/nginx-install.log
```

#### SSL Certificate Management

```bash
# Renew SSL certificate
certbot renew

# Check SSL certificate expiration
certbot certificates

# Manually obtain certificate
sudo certbot --nginx -d yourdomain.com
```

#### Configuration Files

```bash
# Edit main configuration
sudo nano /etc/nginx/nginx.conf

# Edit site configuration
sudo nano /etc/nginx/sites-available/yourdomain.com

# List enabled sites
ls -la /etc/nginx/sites-enabled/
```

---

### 🔧 Troubleshooting

#### ❌ Script fails with "must be run as root"

**Solution:**
```bash
sudo ./install-nginx.sh
```

---

#### ❌ SSL certificate setup fails

**Possible causes:**
- Domain DNS doesn't point to server IP
- Ports 80/443 are blocked
- Firewall is blocking access

**Solutions:**
```bash
# Verify DNS
dig yourdomain.com

# Check firewall
sudo ufw status

# Manually obtain certificate
sudo certbot --nginx -d yourdomain.com
```

---

#### ❌ Nginx configuration test fails

**Solution:**
```bash
# Check configuration syntax
sudo nginx -t

# Review error messages
# Restore from backup if needed
# Backups are saved as: /etc/nginx/nginx.conf.backup.YYYYMMDD_HHMMSS
```

---

#### ❌ Firewall blocking access

**Solution:**
```bash
# Check UFW status
sudo ufw status

# Allow nginx
sudo ufw allow 'Nginx Full'

# Or allow specific ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

---

### 🔐 Security Notes

> **⚠️ Important Security Information**

The script automatically applies the following security best practices:

- ✅ **Server tokens disabled** - Hides nginx version from error pages
- ✅ **Security headers configured** - Protects against common web vulnerabilities
- ✅ **Rate limiting enabled** - Prevents abuse and DoS attacks
- ✅ **SSL/TLS encryption** - Automatic Let's Encrypt certificate setup
- ✅ **Automatic certificate renewal** - Certbot configured for auto-renewal
- ✅ **Configuration backups** - Automatic backups before modifications

**Additional Recommendations:**
- Keep your system updated: `sudo apt update && sudo apt upgrade`
- Regularly review nginx logs for suspicious activity
- Use strong passwords for any admin panels
- Consider setting up fail2ban for additional protection

---

### 📝 License

This script is provided **as-is** for automation purposes. Use at your own risk.

---

### 🤝 Contributing

Contributions are welcome! Feel free to:
- 🐛 Report bugs
- 💡 Suggest improvements
- 🔧 Submit pull requests
- 📖 Improve documentation

---

<div align="center">

**Made with ❤️ for server automation**

</div>
