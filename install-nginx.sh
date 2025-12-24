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
        NGINX_INSTALLED=true
        return 0  # Return 0 to indicate nginx is installed (management mode)
    else
        NGINX_INSTALLED=false
        return 1  # Return 1 to indicate nginx is not installed (installation mode)
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
    
    # Remove any existing explicit include for security-headers.conf to avoid duplicates
    # (wildcard include /etc/nginx/conf.d/*.conf will automatically include it)
    sed -i '/include.*security-headers\.conf/d' "$NGINX_CONF"
    
    # Check if wildcard include for conf.d exists (it will auto-include our file)
    if grep -qE "include.*conf\.d/\*\.conf" "$NGINX_CONF"; then
        print_info "Wildcard include for conf.d/*.conf detected. Security headers will be auto-included."
    else
        # No wildcard, add explicit include
        if ! grep -qE "include.*security-headers\.conf" "$NGINX_CONF"; then
            sed -i '/^http {/a\    include /etc/nginx/conf.d/security-headers.conf;' "$NGINX_CONF"
        fi
    fi
    print_success "Security headers configured"
    
    # Set request size limits
    if ! grep -q "client_max_body_size" "$NGINX_CONF"; then
        sed -i '/^http {/a\    client_max_body_size 10M;' "$NGINX_CONF"
    fi
    print_success "Request size limits configured"
    
    # Create rate limiting configuration
    RATE_LIMIT_CONF="/etc/nginx/conf.d/rate-limit.conf"
    
    # Always create/update the rate-limit.conf file with correct content
    cat > "$RATE_LIMIT_CONF" << 'EOF'
# Rate Limiting
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
EOF
    
    # Remove ALL existing explicit includes for rate-limit.conf to prevent duplicates
    # (wildcard include /etc/nginx/conf.d/*.conf will automatically include it)
    sed -i '/include.*rate-limit\.conf/d' "$NGINX_CONF"
    
    # Check if wildcard include for conf.d exists (it will auto-include our file)
    if grep -qE "include.*conf\.d/\*\.conf" "$NGINX_CONF"; then
        print_info "Wildcard include for conf.d/*.conf detected. Rate limiting will be auto-included."
    else
        # No wildcard, check if zone is already defined directly in nginx.conf
        if grep -E "^\s*limit_req_zone.*zone=general" "$NGINX_CONF" 2>/dev/null | grep -v "^#" | grep -q "zone=general"; then
            print_warning "Rate limiting zone 'general' already defined directly in nginx.conf. Skipping include addition."
        else
            # Add explicit include if needed
            if ! grep -qE "include.*rate-limit\.conf" "$NGINX_CONF"; then
                sed -i '/^http {/a\    include /etc/nginx/conf.d/rate-limit.conf;' "$NGINX_CONF"
            fi
        fi
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

###############################################################################
# Management Mode Functions
###############################################################################

# Function to display management menu
show_management_menu() {
    clear
    echo "=========================================="
    echo "   Nginx Management Menu"
    echo "=========================================="
    echo ""
    echo "  1. Add New Site"
    echo "  2. Remove/Disable Site"
    echo "  3. Manage SSL Certificates"
    echo "  4. Edit/View Configurations"
    echo "  5. View Status and Logs"
    echo "  6. Manage Firewall Rules"
    echo "  7. Reload/Restart Service"
    echo "  8. Exit"
    echo ""
    echo "=========================================="
}

# Function to add new site (Management Mode)
manage_add_site() {
    print_info "Adding new site..."
    
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
    
    # Check if site already exists
    if [[ -f "/etc/nginx/sites-available/$DOMAIN" ]]; then
        print_warning "Site configuration for $DOMAIN already exists."
        read -p "Do you want to overwrite it? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Operation cancelled."
            return
        fi
    fi
    
    # Get document root
    read -p "Enter document root path (default: /var/www/$DOMAIN): " DOCUMENT_ROOT
    DOCUMENT_ROOT=${DOCUMENT_ROOT:-/var/www/$DOMAIN}
    
    # Create document root
    print_info "Creating document root: $DOCUMENT_ROOT"
    mkdir -p "$DOCUMENT_ROOT"
    chown -R www-data:www-data "$DOCUMENT_ROOT"
    chmod -R 755 "$DOCUMENT_ROOT"
    
    # Create index.html if it doesn't exist
    if [[ ! -f "$DOCUMENT_ROOT/index.html" ]]; then
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
    fi
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
    
    # Test and reload
    if nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        systemctl reload nginx
        print_success "Nginx configuration reloaded"
    else
        print_error "Site configuration test failed"
        return 1
    fi
    
    # Ask about SSL
    read -p "Do you want to set up SSL certificate for $DOMAIN? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_ssl "$DOMAIN"
    fi
}

# Function to remove/disable site (Management Mode)
manage_remove_site() {
    print_info "Remove/Disable Site"
    
    # List available sites
    echo ""
    print_info "Available sites:"
    echo ""
    SITES_AVAILABLE=($(ls /etc/nginx/sites-available/ 2>/dev/null | grep -v "default"))
    SITES_ENABLED=($(ls /etc/nginx/sites-enabled/ 2>/dev/null | grep -v "default"))
    
    if [[ ${#SITES_AVAILABLE[@]} -eq 0 ]]; then
        print_warning "No sites available to remove."
        return
    fi
    
    # Show sites with status
    INDEX=1
    for site in "${SITES_AVAILABLE[@]}"; do
        if [[ " ${SITES_ENABLED[@]} " =~ " ${site} " ]]; then
            echo "  $INDEX. $site [ENABLED]"
        else
            echo "  $INDEX. $site [DISABLED]"
        fi
        ((INDEX++))
    done
    
    echo ""
    read -p "Select site number to remove/disable: " SELECTION
    SELECTED_SITE="${SITES_AVAILABLE[$((SELECTION-1))]}"
    
    if [[ -z "$SELECTED_SITE" ]]; then
        print_error "Invalid selection."
        return
    fi
    
    echo ""
    echo "Options for $SELECTED_SITE:"
    echo "  1. Disable (remove symlink, keep config)"
    echo "  2. Delete (remove config file and symlink)"
    echo "  3. Cancel"
    echo ""
    read -p "Choose option (1-3): " OPTION
    
    case $OPTION in
        1)
            if [[ -f "/etc/nginx/sites-enabled/$SELECTED_SITE" ]]; then
                rm "/etc/nginx/sites-enabled/$SELECTED_SITE"
                print_success "Site $SELECTED_SITE disabled"
            else
                print_warning "Site is already disabled"
            fi
            ;;
        2)
            # Get document root before deleting config
            DOC_ROOT=""
            if [[ -f "/etc/nginx/sites-available/$SELECTED_SITE" ]]; then
                DOC_ROOT=$(grep -E "^\s*root\s+" "/etc/nginx/sites-available/$SELECTED_SITE" 2>/dev/null | awk '{print $2}' | tr -d ';')
            fi
            
            if [[ -f "/etc/nginx/sites-enabled/$SELECTED_SITE" ]]; then
                rm "/etc/nginx/sites-enabled/$SELECTED_SITE"
            fi
            if [[ -f "/etc/nginx/sites-available/$SELECTED_SITE" ]]; then
                rm "/etc/nginx/sites-available/$SELECTED_SITE"
                print_success "Site $SELECTED_SITE deleted"
            fi
            
            if [[ -n "$DOC_ROOT" && -d "$DOC_ROOT" ]]; then
                read -p "Do you want to remove document root ($DOC_ROOT)? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -rf "$DOC_ROOT"
                    print_success "Document root removed"
                fi
            fi
            ;;
        3)
            print_info "Operation cancelled"
            return
            ;;
        *)
            print_error "Invalid option"
            return
            ;;
    esac
    
    # Test and reload
    if nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        systemctl reload nginx
        print_success "Nginx configuration reloaded"
    else
        print_error "Configuration test failed"
    fi
}

# Function to manage SSL certificates (Management Mode)
manage_ssl() {
    print_info "SSL Certificate Management"
    echo ""
    echo "  1. List all certificates"
    echo "  2. Renew specific certificate"
    echo "  3. Renew all certificates"
    echo "  4. Add certificate for existing site"
    echo "  5. Check certificate expiration"
    echo "  6. Test certificate renewal (dry-run)"
    echo "  7. Back to main menu"
    echo ""
    read -p "Choose option (1-7): " SSL_OPTION
    
    case $SSL_OPTION in
        1)
            print_info "Listing all certificates:"
            certbot certificates
            ;;
        2)
            certbot certificates
            echo ""
            read -p "Enter domain name to renew: " DOMAIN
            certbot renew --cert-name "$DOMAIN" --force-renewal
            systemctl reload nginx
            ;;
        3)
            print_info "Renewing all certificates..."
            certbot renew
            systemctl reload nginx
            print_success "All certificates renewed"
            ;;
        4)
            read -p "Enter domain name: " DOMAIN
            if validate_domain "$DOMAIN"; then
                setup_ssl "$DOMAIN"
            else
                print_error "Invalid domain name"
            fi
            ;;
        5)
            print_info "Certificate expiration dates:"
            certbot certificates | grep -E "Certificate Name|Expiry Date"
            ;;
        6)
            print_info "Testing certificate renewal (dry-run)..."
            certbot renew --dry-run
            ;;
        7)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# Function to edit/view configurations (Management Mode)
manage_edit_config() {
    print_info "Edit/View Configurations"
    echo ""
    echo "  1. View main nginx configuration"
    echo "  2. View specific site configuration"
    echo "  3. Edit main nginx configuration"
    echo "  4. Edit site configuration"
    echo "  5. View security headers configuration"
    echo "  6. View rate limiting configuration"
    echo "  7. Backup configuration"
    echo "  8. Back to main menu"
    echo ""
    read -p "Choose option (1-8): " CONFIG_OPTION
    
    case $CONFIG_OPTION in
        1)
            less /etc/nginx/nginx.conf
            ;;
        2)
            SITES=($(ls /etc/nginx/sites-available/ 2>/dev/null | grep -v "default"))
            if [[ ${#SITES[@]} -eq 0 ]]; then
                print_warning "No sites available"
                return
            fi
            INDEX=1
            for site in "${SITES[@]}"; do
                echo "  $INDEX. $site"
                ((INDEX++))
            done
            read -p "Select site number: " SELECTION
            SELECTED_SITE="${SITES[$((SELECTION-1))]}"
            if [[ -n "$SELECTED_SITE" ]]; then
                less "/etc/nginx/sites-available/$SELECTED_SITE"
            fi
            ;;
        3)
            backup_config
            ${EDITOR:-nano} /etc/nginx/nginx.conf
            if nginx -t; then
                systemctl reload nginx
                print_success "Configuration updated and reloaded"
            else
                print_error "Configuration test failed. Please fix errors."
            fi
            ;;
        4)
            SITES=($(ls /etc/nginx/sites-available/ 2>/dev/null | grep -v "default"))
            if [[ ${#SITES[@]} -eq 0 ]]; then
                print_warning "No sites available"
                return
            fi
            INDEX=1
            for site in "${SITES[@]}"; do
                echo "  $INDEX. $site"
                ((INDEX++))
            done
            read -p "Select site number: " SELECTION
            SELECTED_SITE="${SITES[$((SELECTION-1))]}"
            if [[ -n "$SELECTED_SITE" ]]; then
                ${EDITOR:-nano} "/etc/nginx/sites-available/$SELECTED_SITE"
                if nginx -t; then
                    systemctl reload nginx
                    print_success "Configuration updated and reloaded"
                else
                    print_error "Configuration test failed. Please fix errors."
                fi
            fi
            ;;
        5)
            if [[ -f "/etc/nginx/conf.d/security-headers.conf" ]]; then
                cat /etc/nginx/conf.d/security-headers.conf
            else
                print_warning "Security headers configuration not found"
            fi
            ;;
        6)
            if [[ -f "/etc/nginx/conf.d/rate-limit.conf" ]]; then
                cat /etc/nginx/conf.d/rate-limit.conf
            else
                print_warning "Rate limiting configuration not found"
            fi
            ;;
        7)
            backup_config
            print_success "Configuration backed up"
            ;;
        8)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# Function to view status and logs (Management Mode)
manage_view_status() {
    print_info "View Status and Logs"
    echo ""
    echo "  1. Nginx service status"
    echo "  2. Nginx version"
    echo "  3. List enabled sites"
    echo "  4. View error log (real-time)"
    echo "  5. View access log (real-time)"
    echo "  6. View installation log"
    echo "  7. Show active connections"
    echo "  8. Show nginx process information"
    echo "  9. Back to main menu"
    echo ""
    read -p "Choose option (1-9): " STATUS_OPTION
    
    case $STATUS_OPTION in
        1)
            systemctl status nginx
            ;;
        2)
            nginx -v
            ;;
        3)
            print_info "Enabled sites:"
            ls -la /etc/nginx/sites-enabled/ 2>/dev/null | grep -v "^total" | awk '{print $9}'
            ;;
        4)
            print_info "Viewing error log (Ctrl+C to exit)..."
            tail -f /var/log/nginx/error.log
            ;;
        5)
            print_info "Viewing access log (Ctrl+C to exit)..."
            tail -f /var/log/nginx/access.log
            ;;
        6)
            if [[ -f "$LOG_FILE" ]]; then
                less "$LOG_FILE"
            else
                print_warning "Installation log not found"
            fi
            ;;
        7)
            netstat -an | grep -E ":80|:443" | grep ESTABLISHED | wc -l
            print_info "Active connections shown above"
            ;;
        8)
            ps aux | grep nginx | grep -v grep
            ;;
        9)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# Function to manage firewall (Management Mode)
manage_firewall() {
    print_info "Manage Firewall Rules"
    
    if ! command -v ufw &> /dev/null; then
        print_warning "UFW is not installed."
        return
    fi
    
    echo ""
    echo "  1. View firewall status"
    echo "  2. Allow HTTP/HTTPS (ports 80/443)"
    echo "  3. Remove HTTP/HTTPS rules"
    echo "  4. Check if ports 80/443 are open"
    echo "  5. Back to main menu"
    echo ""
    read -p "Choose option (1-5): " FW_OPTION
    
    case $FW_OPTION in
        1)
            ufw status verbose
            ;;
        2)
            ufw allow 'Nginx Full'
            print_success "Firewall rules added"
            ;;
        3)
            ufw delete allow 'Nginx Full'
            print_success "Firewall rules removed"
            ;;
        4)
            if ufw status | grep -qE "80|443"; then
                print_success "Ports 80/443 are open"
            else
                print_warning "Ports 80/443 are not open"
            fi
            ;;
        5)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# Function to reload/restart service (Management Mode)
manage_service_control() {
    print_info "Reload/Restart Service"
    echo ""
    echo "  1. Test nginx configuration"
    echo "  2. Reload nginx (graceful)"
    echo "  3. Restart nginx (full restart)"
    echo "  4. Stop nginx"
    echo "  5. Start nginx"
    echo "  6. Enable nginx on boot"
    echo "  7. Disable nginx on boot"
    echo "  8. Back to main menu"
    echo ""
    read -p "Choose option (1-8): " SERVICE_OPTION
    
    case $SERVICE_OPTION in
        1)
            if nginx -t; then
                print_success "Configuration test passed"
            else
                print_error "Configuration test failed"
            fi
            ;;
        2)
            if nginx -t; then
                systemctl reload nginx
                print_success "Nginx reloaded"
            else
                print_error "Configuration test failed. Cannot reload."
            fi
            ;;
        3)
            if nginx -t; then
                systemctl restart nginx
                print_success "Nginx restarted"
            else
                print_error "Configuration test failed. Cannot restart."
            fi
            ;;
        4)
            systemctl stop nginx
            print_success "Nginx stopped"
            ;;
        5)
            systemctl start nginx
            print_success "Nginx started"
            ;;
        6)
            systemctl enable nginx
            print_success "Nginx enabled on boot"
            ;;
        7)
            systemctl disable nginx
            print_success "Nginx disabled on boot"
            ;;
        8)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# Function to run management mode
run_management_mode() {
    NGINX_VERSION=$(nginx -v 2>&1 | awk -F/ '{print $2}')
    
    while true; do
        show_management_menu
        read -p "Select an option (1-8): " MENU_CHOICE
        
        case $MENU_CHOICE in
            1)
                manage_add_site
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                manage_remove_site
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                manage_ssl
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                manage_edit_config
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                manage_view_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                manage_firewall
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                manage_service_control
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                print_info "Exiting management mode. Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-8."
                sleep 2
                ;;
        esac
    done
}

# Main execution
main() {
    # Initialize log file
    touch "$LOG_FILE"
    
    # Check root and OS first
    check_root
    detect_os
    
    # Check if nginx is installed - if yes, enter management mode
    if check_nginx_installed; then
        NGINX_VERSION=$(nginx -v 2>&1 | awk -F/ '{print $2}')
        echo "=========================================="
        echo "Nginx Management Mode"
        echo "Nginx version: $NGINX_VERSION"
        echo "=========================================="
        echo ""
        echo "Management started at $(date)" >> "$LOG_FILE"
        run_management_mode
    else
        # Nginx not installed - proceed with installation
        echo "=========================================="
        echo "Nginx Installation Automation Script"
        echo "=========================================="
        echo ""
        
        echo "Installation started at $(date)" >> "$LOG_FILE"
        
        # Run installation steps
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
    fi
}

# Trap errors
trap 'print_error "Script failed at line $LINENO. Check $LOG_FILE for details."' ERR

# Run main function
main "$@"

