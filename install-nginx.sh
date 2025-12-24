#!/bin/bash

###############################################################################
# Nginx Installation Automation Script for Ubuntu-based Servers
# This script automates nginx installation with security hardening and
# interactive configuration options following 2024 best practices.
###############################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/nginx-install.log"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
    print_success "Running with root privileges"
}

# Function to detect Ubuntu/Debian-based system
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
            print_error "This script is designed for Ubuntu/Debian-based systems. Detected: $ID"
            exit 1
        fi
        print_success "Detected OS: $PRETTY_NAME"
    else
        print_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
}

# Function to check if nginx is already installed
check_nginx_installed() {
    if command -v nginx &> /dev/null; then
        NGINX_VERSION=$(nginx -v 2>&1 | awk -F/ '{print $2}')
        print_warning "Nginx is already installed (version: $NGINX_VERSION)"
        read -p "Do you want to continue with configuration updates? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled by user"
            exit 0
        fi
        NGINX_INSTALLED=true
    else
        NGINX_INSTALLED=false
        print_info "Nginx is not installed. Proceeding with installation."
    fi
}

# Function to display system information
display_system_info() {
    print_info "Gathering system information..."
    echo "----------------------------------------"
    echo "OS Version: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "CPU Cores: $(nproc)"
    echo "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "Disk Space: $(df -h / | awk 'NR==2 {print $4}') available"
    echo "----------------------------------------"
}

# Function to update system packages
update_system() {
    print_info "Updating package lists..."
    apt update -qq
    print_success "Package lists updated"
    
    print_info "Upgrading existing packages..."
    apt upgrade -y -qq
    print_success "System packages upgraded"
}

# Function to install nginx
install_nginx() {
    if [[ "$NGINX_INSTALLED" == true ]]; then
        print_info "Nginx already installed, skipping installation step"
        return
    fi
    
    print_info "Installing nginx..."
    apt install -y nginx
    print_success "Nginx installed successfully"
    
    # Verify installation
    if command -v nginx &> /dev/null; then
        NGINX_VERSION=$(nginx -v 2>&1 | awk -F/ '{print $2}')
        print_success "Nginx version $NGINX_VERSION verified"
    else
        print_error "Nginx installation verification failed"
        exit 1
    fi
}

# Function to configure firewall
configure_firewall() {
    if command -v ufw &> /dev/null; then
        UFW_STATUS=$(ufw status | head -n 1 | awk '{print $2}')
        print_info "UFW status: $UFW_STATUS"
        
        if [[ "$UFW_STATUS" == "active" ]]; then
            read -p "Do you want to configure firewall rules? (Allow HTTP/HTTPS) (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Configuring UFW to allow HTTP (port 80) and HTTPS (port 443)..."
                ufw allow 'Nginx Full'
                print_success "Firewall rules configured"
            else
                print_warning "Firewall configuration skipped"
            fi
        else
            print_warning "UFW is not active. Skipping firewall configuration."
        fi
    else
        print_warning "UFW is not installed. Skipping firewall configuration."
    fi
    
    # Display firewall status
    if command -v ufw &> /dev/null; then
        print_info "Current firewall status:"
        ufw status | tee -a "$LOG_FILE"
    fi
}

# Function to backup nginx configuration
backup_config() {
    if [[ -f /etc/nginx/nginx.conf ]]; then
        BACKUP_FILE="/etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)"
        cp /etc/nginx/nginx.conf "$BACKUP_FILE"
        print_success "Configuration backed up to $BACKUP_FILE"
    fi
}

# Function to apply security hardening
apply_security_hardening() {
    print_info "Applying security hardening..."
    backup_config
    
    NGINX_CONF="/etc/nginx/nginx.conf"
    
    # Disable server tokens
    if grep -q "server_tokens" "$NGINX_CONF"; then
        sed -i 's/.*server_tokens.*/    server_tokens off;/' "$NGINX_CONF"
    else
        # Add after http block opening
        sed -i '/^http {/a\    server_tokens off;' "$NGINX_CONF"
    fi
    print_success "Server tokens disabled"
    
    # Ensure conf.d directory exists
    mkdir -p /etc/nginx/conf.d
    
    # Create security headers configuration file
    SECURITY_CONF="/etc/nginx/conf.d/security-headers.conf"
    cat > "$SECURITY_CONF" << 'EOF'
# Security Headers
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
EOF
    
    # Include security headers in main config
    if ! grep -q "conf.d/security-headers.conf" "$NGINX_CONF"; then
        sed -i '/^http {/a\    include /etc/nginx/conf.d/security-headers.conf;' "$NGINX_CONF"
    fi
    print_success "Security headers configured"
    
    # Set request size limits
    if ! grep -q "client_max_body_size" "$NGINX_CONF"; then
        sed -i '/^http {/a\    client_max_body_size 10M;' "$NGINX_CONF"
    fi
    print_success "Request size limits configured"
    
    # Create rate limiting configuration
    RATE_LIMIT_CONF="/etc/nginx/conf.d/rate-limit.conf"
    cat > "$RATE_LIMIT_CONF" << 'EOF'
# Rate Limiting
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
EOF
    
    # Include rate limiting in main config
    if ! grep -q "conf.d/rate-limit.conf" "$NGINX_CONF"; then
        sed -i '/^http {/a\    include /etc/nginx/conf.d/rate-limit.conf;' "$NGINX_CONF"
    fi
    print_success "Rate limiting configured"
}

# Function to optimize performance
optimize_performance() {
    print_info "Optimizing nginx performance..."
    
    NGINX_CONF="/etc/nginx/nginx.conf"
    
    # Set worker processes to auto
    if grep -q "^worker_processes" "$NGINX_CONF"; then
        sed -i 's/^worker_processes.*/worker_processes auto;/' "$NGINX_CONF"
    else
        sed -i '/^worker_processes/a\worker_processes auto;' "$NGINX_CONF"
    fi
    print_success "Worker processes set to auto"
    
    # Optimize worker connections
    if grep -q "worker_connections" "$NGINX_CONF"; then
        sed -i 's/worker_connections.*/worker_connections 1024;/' "$NGINX_CONF"
    fi
    print_success "Worker connections optimized"
    
    # Enable gzip compression
    if ! grep -q "gzip on" "$NGINX_CONF"; then
        cat >> "$NGINX_CONF" << 'EOF'

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
EOF
    fi
    print_success "Gzip compression enabled"
}

# Function to manage nginx service
manage_service() {
    print_info "Managing nginx service..."
    
    # Test configuration
    if nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Nginx configuration test passed"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi
    
    # Start and enable nginx
    systemctl start nginx
    systemctl enable nginx
    print_success "Nginx service started and enabled"
    
    # Verify nginx is running
    if systemctl is-active --quiet nginx; then
        print_success "Nginx is running"
    else
        print_error "Nginx failed to start"
        exit 1
    fi
}

# Function to validate domain name
validate_domain() {
    local domain=$1
    if [[ -z "$domain" ]]; then
        return 1
    fi
    
    # Basic domain validation regex
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to set up site configuration
setup_site() {
    read -p "Do you want to set up a website? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Site setup skipped"
        return
    fi
    
    # Get domain name
    while true; do
        read -p "Enter domain name (e.g., example.com): " DOMAIN
        if validate_domain "$DOMAIN"; then
            print_success "Domain validated: $DOMAIN"
            break
        else
            print_error "Invalid domain name. Please try again."
        fi
    done
    
    # Get document root (optional)
    read -p "Enter document root path (default: /var/www/$DOMAIN): " DOCUMENT_ROOT
    DOCUMENT_ROOT=${DOCUMENT_ROOT:-/var/www/$DOMAIN}
    
    # Create document root
    print_info "Creating document root: $DOCUMENT_ROOT"
    mkdir -p "$DOCUMENT_ROOT"
    chown -R www-data:www-data "$DOCUMENT_ROOT"
    chmod -R 755 "$DOCUMENT_ROOT"
    
    # Create index.html
    cat > "$DOCUMENT_ROOT/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $DOMAIN</title>
</head>
<body>
    <h1>Welcome to $DOMAIN</h1>
    <p>Nginx is working correctly!</p>
</body>
</html>
EOF
    print_success "Document root created"
    
    # Create nginx site configuration
    SITE_CONFIG="/etc/nginx/sites-available/$DOMAIN"
    cat > "$SITE_CONFIG" << EOF
# HTTP Server Block
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    root $DOCUMENT_ROOT;
    index index.html index.htm index.nginx-debian.html;
    
    location / {
        limit_req zone=general burst=20 nodelay;
        try_files \$uri \$uri/ =404;
    }
    
    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;
}
EOF
    
    # Enable site
    if [[ -f "/etc/nginx/sites-enabled/$DOMAIN" ]]; then
        rm "/etc/nginx/sites-enabled/$DOMAIN"
    fi
    ln -s "$SITE_CONFIG" "/etc/nginx/sites-enabled/$DOMAIN"
    print_success "Site configuration created and enabled"
    
    # Test configuration
    if nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        systemctl reload nginx
        print_success "Nginx configuration reloaded"
    else
        print_error "Site configuration test failed"
        return 1
    fi
    
    # Set up SSL with Let's Encrypt
    setup_ssl "$DOMAIN"
}

# Function to set up SSL with Let's Encrypt
setup_ssl() {
    local domain=$1
    
    print_info "Setting up SSL certificate for $domain..."
    
    # Install certbot
    if ! command -v certbot &> /dev/null; then
        print_info "Installing certbot and nginx plugin..."
        apt install -y certbot python3-certbot-nginx
        print_success "Certbot installed"
    else
        print_info "Certbot already installed"
    fi
    
    # Obtain certificate
    print_info "Obtaining SSL certificate from Let's Encrypt..."
    if certbot --nginx -d "$domain" -d "www.$domain" --non-interactive --agree-tos --register-unsafely-without-email --redirect; then
        print_success "SSL certificate obtained and configured"
        
        # Test automatic renewal
        if certbot renew --dry-run &> /dev/null; then
            print_success "Automatic renewal test passed"
        else
            print_warning "Automatic renewal test failed, but certificate is installed"
        fi
    else
        print_warning "SSL certificate setup failed. You can run 'certbot --nginx -d $domain' manually later."
        print_info "Make sure your domain DNS points to this server before obtaining a certificate."
    fi
}

# Function to display post-installation summary
post_installation_summary() {
    echo ""
    echo "=========================================="
    print_success "Nginx Installation Complete!"
    echo "=========================================="
    echo ""
    
    # Display nginx status
    print_info "Nginx Status:"
    systemctl status nginx --no-pager -l | head -n 10
    
    echo ""
    print_info "Nginx Version:"
    nginx -v 2>&1
    
    echo ""
    print_info "Active Sites:"
    ls -la /etc/nginx/sites-enabled/ 2>/dev/null | grep -v "^total" | awk '{print $9}' || echo "No sites enabled"
    
    echo ""
    print_info "Useful Commands:"
    echo "  - Check nginx status: systemctl status nginx"
    echo "  - Test configuration: nginx -t"
    echo "  - Reload nginx: systemctl reload nginx"
    echo "  - Restart nginx: systemctl restart nginx"
    echo "  - View error log: tail -f /var/log/nginx/error.log"
    echo "  - View access log: tail -f /var/log/nginx/access.log"
    echo "  - Renew SSL certificate: certbot renew"
    
    echo ""
    print_info "Configuration Files:"
    echo "  - Main config: /etc/nginx/nginx.conf"
    echo "  - Site configs: /etc/nginx/sites-available/"
    echo "  - Enabled sites: /etc/nginx/sites-enabled/"
    echo "  - Security headers: /etc/nginx/conf.d/security-headers.conf"
    echo "  - Rate limiting: /etc/nginx/conf.d/rate-limit.conf"
    
    echo ""
    print_info "Installation log saved to: $LOG_FILE"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "Nginx Installation Automation Script"
    echo "=========================================="
    echo ""
    
    # Initialize log file
    touch "$LOG_FILE"
    echo "Installation started at $(date)" >> "$LOG_FILE"
    
    # Run installation steps
    check_root
    detect_os
    check_nginx_installed
    display_system_info
    update_system
    install_nginx
    configure_firewall
    apply_security_hardening
    optimize_performance
    manage_service
    setup_site
    post_installation_summary
    
    echo "Installation completed at $(date)" >> "$LOG_FILE"
    print_success "All done! Nginx is ready to use."
}

# Trap errors
trap 'print_error "Script failed at line $LINENO. Check $LOG_FILE for details."' ERR

# Run main function
main "$@"

