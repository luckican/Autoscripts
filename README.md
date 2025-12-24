# Autoscripts

A collection of automation scripts for server management and deployment.

## Scripts

### install-nginx.sh

Automated nginx installation script for Ubuntu-based servers (Ubuntu/Debian) with security hardening and interactive configuration options following 2024 best practices.

#### Features

- **Pre-installation Checks**: Verifies root privileges, detects OS, checks for existing nginx installation, displays system information
- **System Preparation**: Updates package lists and upgrades existing packages
- **Nginx Installation**: Installs nginx from official Ubuntu repositories
- **Interactive Firewall Configuration**: Optionally configures UFW to allow HTTP/HTTPS traffic
- **Security Hardening**:
  - Disables server tokens (hides nginx version)
  - Adds security headers (X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy)
  - Sets request size limits
  - Configures rate limiting
- **Performance Optimization**:
  - Sets worker processes to auto (matches CPU cores)
  - Enables gzip compression
  - Optimizes worker connections
- **Service Management**: Starts and enables nginx, verifies it's running, tests configuration
- **Interactive Site Setup**: 
  - Prompts for domain name
  - Creates site configuration
  - Sets up document root
  - Automatically configures Let's Encrypt SSL certificates
- **Post-installation Summary**: Displays status, version, active sites, and useful commands

#### Requirements

- Ubuntu or Debian-based Linux distribution
- Root or sudo privileges
- Internet connection for package downloads
- Git (for cloning the repository)

#### Quick Start (Git Clone)

1. Clone the repository on your server:
   ```bash
   git clone <repository-url> /tmp/autoscripts
   cd /tmp/autoscripts
   ```

   Or clone to a permanent location:
   ```bash
   git clone <repository-url> ~/autoscripts
   cd ~/autoscripts
   ```

2. Run the script with sudo:
   ```bash
   sudo ./install-nginx.sh
   ```

   **Note**: Replace `<repository-url>` with your actual git repository URL (e.g., `https://github.com/username/autoscripts.git` or `git@github.com:username/autoscripts.git`)

#### Usage (Manual Copy)

1. Copy the script to your server:
   ```bash
   scp install-nginx.sh user@your-server:/tmp/
   ```

2. SSH into your server:
   ```bash
   ssh user@your-server
   ```

3. Make the script executable:
   ```bash
   chmod +x /tmp/install-nginx.sh
   ```

4. Run the script with sudo:
   ```bash
   sudo /tmp/install-nginx.sh
   ```

5. Follow the interactive prompts:
   - Configure firewall rules? (y/n)
   - Set up a website? (y/n)
   - Enter domain name (if setting up a website)
   - Enter document root path (optional, defaults to /var/www/domain.com)

#### What the Script Does

1. Checks system requirements and displays system information
2. Updates system packages
3. Installs nginx
4. Optionally configures firewall (UFW) for HTTP/HTTPS
5. Applies security hardening configurations
6. Optimizes nginx performance settings
7. Starts and enables nginx service
8. Optionally sets up a website with SSL certificate

#### Configuration Files Created

- `/etc/nginx/nginx.conf` - Main nginx configuration (modified)
- `/etc/nginx/conf.d/security-headers.conf` - Security headers configuration
- `/etc/nginx/conf.d/rate-limit.conf` - Rate limiting configuration
- `/etc/nginx/sites-available/domain.com` - Site configuration (if site setup is chosen)
- `/etc/nginx/sites-enabled/domain.com` - Enabled site symlink

#### Logging

All installation actions are logged to `/var/log/nginx-install.log`

#### Post-Installation

After installation, the script displays:
- Nginx service status
- Installed nginx version
- Active sites
- Useful commands for managing nginx
- Configuration file locations

#### Useful Commands

```bash
# Check nginx status
systemctl status nginx

# Test nginx configuration
nginx -t

# Reload nginx (after config changes)
systemctl reload nginx

# Restart nginx
systemctl restart nginx

# View error log
tail -f /var/log/nginx/error.log

# View access log
tail -f /var/log/nginx/access.log

# Renew SSL certificate
certbot renew

# Check SSL certificate expiration
certbot certificates
```

#### Troubleshooting

**Script fails with "must be run as root"**
- Run the script with `sudo`

**SSL certificate setup fails**
- Ensure your domain DNS points to the server's IP address
- Make sure ports 80 and 443 are open and accessible
- Run manually: `sudo certbot --nginx -d yourdomain.com`

**Nginx configuration test fails**
- Check the error message: `sudo nginx -t`
- Review the configuration files mentioned in the error
- Restore from backup if needed (backups are created automatically)

**Firewall blocking access**
- Check UFW status: `sudo ufw status`
- Allow nginx: `sudo ufw allow 'Nginx Full'`

#### Security Notes

- The script automatically applies security best practices
- Server tokens are disabled to hide nginx version
- Security headers are configured to protect against common vulnerabilities
- Rate limiting is enabled to prevent abuse
- SSL certificates are automatically renewed via certbot

#### License

This script is provided as-is for automation purposes. Use at your own risk.

#### Contributing

Feel free to submit improvements, bug fixes, or additional features.

