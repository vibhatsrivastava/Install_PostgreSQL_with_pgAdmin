#!/bin/bash
# =============================================================================
# Apache Domain Configuration Script for pgAdmin
# =============================================================================
# This script configures a custom domain for pgAdmin with optional SSL support.
# pgAdmin is served directly via WSGI at /pgadmin4/ (no reverse proxy needed).
#
# Prerequisites:
# - PostgreSQL and pgAdmin must be already installed
# - Run install_postgresql_pgadmin.sh first
# - Ubuntu 24.04 LTS (recommended)
# - Root/sudo privileges
#
# Usage:
#   sudo bash install_apache_reverse_proxy.sh
#
# Features:
# - Configures custom domain for pgAdmin (e.g., postgresql.local)
# - Adds local domain to /etc/hosts
# - Optional self-signed SSL certificate
# - Automatic rollback on failure
# - Comprehensive logging
# =============================================================================

# Exit immediately if a command exits with a non-zero status
set -e
# Treat unset variables as an error
set -u
# Return value of a pipeline is the status of the last command to exit with a non-zero status
set -o pipefail

# =============================================================================
# Color Definitions
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Global Variables
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/configs/install_config_proxy.conf"
TEMP_LOG_FILE="/tmp/apache_proxy_install_$$.log"

# State tracking flags for rollback
INSTALLATION_STARTED=false
MODULES_ENABLED=false
VHOST_CREATED=false
SSL_CONFIGURED=false
HOSTS_MODIFIED=false
BACKUP_DIR=""

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE:-$TEMP_LOG_FILE}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE:-$TEMP_LOG_FILE}"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE:-$TEMP_LOG_FILE}"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE:-$TEMP_LOG_FILE}"
}

# =============================================================================
# Banner Display
# =============================================================================

display_banner() {
    echo -e "${GREEN}"
    echo "============================================================================="
    echo "        Apache Domain Setup for pgAdmin"
    echo "============================================================================="
    echo -e "${NC}"
    log_info "Starting Apache domain configuration..."
}

# =============================================================================
# Pre-flight Check Functions
# =============================================================================

check_root() {
    log_info "Checking root privileges..."
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
    log_success "Root privileges confirmed"
}

check_ubuntu_version() {
    log_info "Checking Ubuntu version..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" != "ubuntu" ]; then
            log_warning "This script is designed for Ubuntu. Detected: $ID"
            log_warning "Continuing anyway, but some commands may fail..."
        elif [ "$VERSION_ID" != "24.04" ]; then
            log_warning "This script is optimized for Ubuntu 24.04. Detected: $VERSION_ID"
            log_warning "Continuing anyway, but compatibility is not guaranteed..."
        else
            log_success "Ubuntu 24.04 detected"
        fi
    else
        log_warning "Cannot determine OS version. Continuing anyway..."
    fi
}

check_apache_exists() {
    log_info "Checking if Apache is installed..."
    
    if ! command -v apache2 &> /dev/null; then
        log_error "Apache is not installed!"
        log_error "Please run install_postgresql_pgadmin.sh first to install pgAdmin (which includes Apache)"
        exit 1
    fi
    
    log_success "Apache is installed"
    
    log_info "Checking if Apache is running..."
    if ! systemctl is-active --quiet apache2; then
        log_error "Apache is not running!"
        log_error "Please start Apache or check the pgAdmin installation"
        exit 1
    fi
    
    log_success "Apache is running"
}

check_pgadmin_exists() {
    log_info "Checking if pgAdmin is accessible..."
    
    # Test if pgAdmin is responding on Apache
    if curl -s http://127.0.0.1/pgadmin4/ > /dev/null 2>&1; then
        log_success "pgAdmin is accessible via Apache"
    else
        log_error "Cannot access pgAdmin at http://127.0.0.1/pgadmin4/"
        log_error "Please ensure pgAdmin is properly installed and configured"
        exit 1
    fi
}

# =============================================================================
# Configuration Loading and Validation
# =============================================================================

load_config() {
    log_info "Loading configuration from ${CONFIG_FILE}..."
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        exit 1
    fi
    
    # Source the configuration file
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
    
    # Transfer to the configured log file location
    if [ -n "${LOG_FILE:-}" ]; then
        cat "${TEMP_LOG_FILE}" >> "${LOG_FILE}"
        rm -f "${TEMP_LOG_FILE}"
        TEMP_LOG_FILE="${LOG_FILE}"
    fi
    
    log_success "Configuration loaded successfully"
    
    # Validate required variables
    log_info "Validating configuration..."
    
    if [ -z "${DOMAIN_NAME:-}" ]; then
        log_error "DOMAIN_NAME is not set in configuration file"
        exit 1
    fi
    
    if [ -z "${ENABLE_SSL:-}" ]; then
        log_error "ENABLE_SSL is not set in configuration file"
        exit 1
    fi
    
    if [ "${ENABLE_SSL}" != "yes" ] && [ "${ENABLE_SSL}" != "no" ]; then
        log_error "ENABLE_SSL must be 'yes' or 'no', got: ${ENABLE_SSL}"
        exit 1
    fi
    
    # Validate SSL configuration if SSL is enabled
    if [ "${ENABLE_SSL}" = "yes" ]; then
        if [ -z "${SSL_COUNTRY:-}" ] || [ -z "${SSL_STATE:-}" ] || [ -z "${SSL_CITY:-}" ] || [ -z "${SSL_ORG:-}" ]; then
            log_error "SSL is enabled but SSL certificate details are incomplete"
            exit 1
        fi
    fi
    
    if [ -z "${APACHE_CONFIG_NAME:-}" ]; then
        log_error "APACHE_CONFIG_NAME is not set in configuration file"
        exit 1
    fi
    
    # Note: PGADMIN_BACKEND is no longer required as we use WSGI directly
    # instead of proxying to avoid redirect loops
    
    log_success "Configuration validated successfully"
    log_info "Domain: ${DOMAIN_NAME}"
    log_info "SSL Enabled: ${ENABLE_SSL}"
    log_info "Apache Config Name: ${APACHE_CONFIG_NAME}"
}

# =============================================================================
# Backup Functions
# =============================================================================

create_backup() {
    log_info "Creating backup of existing configurations..."
    
    BACKUP_DIR="${BACKUP_BASE_DIR}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "${BACKUP_DIR}"
    
    log_info "Backup directory: ${BACKUP_DIR}"
    
    # Backup /etc/hosts
    if [ -f /etc/hosts ]; then
        cp /etc/hosts "${BACKUP_DIR}/hosts.backup"
        log_success "Backed up /etc/hosts"
    fi
    
    # Backup existing VirtualHost config if it exists
    local vhost_config="/etc/apache2/sites-available/${APACHE_CONFIG_NAME}.conf"
    if [ -f "${vhost_config}" ]; then
        cp "${vhost_config}" "${BACKUP_DIR}/${APACHE_CONFIG_NAME}.conf.backup"
        log_success "Backed up existing VirtualHost config"
    fi
    
    # Backup ports.conf just in case
    if [ -f /etc/apache2/ports.conf ]; then
        cp /etc/apache2/ports.conf "${BACKUP_DIR}/ports.conf.backup"
        log_success "Backed up /etc/apache2/ports.conf"
    fi
    
    log_success "Backup created successfully"
}

# =============================================================================
# Apache Module Management
# =============================================================================

enable_apache_modules() {
    log_info "Enabling required Apache modules..."
    
    # Note: proxy modules not needed since we use WSGI directly
    local modules=("headers" "rewrite")
    
    if [ "${ENABLE_SSL}" = "yes" ]; then
        modules+=("ssl" "socache_shmcb")
    fi
    
    for module in "${modules[@]}"; do
        if ! apache2ctl -M 2>/dev/null | grep -q "${module}_module"; then
            log_info "Enabling module: ${module}"
            a2enmod "${module}" > /dev/null 2>&1
            log_success "Enabled module: ${module}"
        else
            log_info "Module already enabled: ${module}"
        fi
    done
    
    MODULES_ENABLED=true
    log_success "All required Apache modules are enabled"
}

# =============================================================================
# SSL Certificate Generation
# =============================================================================

generate_ssl_certificate() {
    if [ "${ENABLE_SSL}" != "yes" ]; then
        log_info "SSL is disabled, skipping certificate generation"
        return 0
    fi
    
    log_info "Generating self-signed SSL certificate..."
    
    local ssl_dir="/etc/apache2/ssl/${DOMAIN_NAME}"
    mkdir -p "${ssl_dir}"
    
    local cert_file="${ssl_dir}/${DOMAIN_NAME}.crt"
    local key_file="${ssl_dir}/${DOMAIN_NAME}.key"
    
    # Generate self-signed certificate
    openssl req -x509 -nodes -days "${SSL_DAYS_VALID:-365}" \
        -newkey rsa:2048 \
        -keyout "${key_file}" \
        -out "${cert_file}" \
        -subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_CITY}/O=${SSL_ORG}/OU=${SSL_ORG_UNIT:-IT}/CN=${SSL_COMMON_NAME:-$DOMAIN_NAME}" \
        > /dev/null 2>&1
    
    # Secure the private key
    chmod 600 "${key_file}"
    chmod 644 "${cert_file}"
    
    SSL_CONFIGURED=true
    log_success "SSL certificate generated successfully"
    log_info "Certificate: ${cert_file}"
    log_info "Private Key: ${key_file}"
}

# =============================================================================
# VirtualHost Configuration
# =============================================================================

create_vhost_config() {
    log_info "Creating Apache VirtualHost configuration..."
    
    local vhost_config="/etc/apache2/sites-available/${APACHE_CONFIG_NAME}.conf"
    
    # Create the VirtualHost configuration
    cat > "${vhost_config}" <<EOF
# =============================================================================
# Apache VirtualHost Configuration for pgAdmin
# Generated by install_apache_reverse_proxy.sh
# Date: $(date)
# pgAdmin is served via WSGI at /pgadmin4/ (no reverse proxy)
# =============================================================================

# HTTP VirtualHost
<VirtualHost *:${HTTP_PORT:-80}>
    ServerName ${DOMAIN_NAME}
    
    # Logging
    ErrorLog \${APACHE_LOG_DIR}/${APACHE_CONFIG_NAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${APACHE_CONFIG_NAME}_access.log combined
    
EOF

    if [ "${ENABLE_SSL}" = "yes" ]; then
        # Add redirect to HTTPS
        cat >> "${vhost_config}" <<EOF
    # Redirect all HTTP traffic to HTTPS
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [R=301,L]
</VirtualHost>

# HTTPS VirtualHost
<VirtualHost *:${HTTPS_PORT:-443}>
    ServerName ${DOMAIN_NAME}
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/${DOMAIN_NAME}/${DOMAIN_NAME}.crt
    SSLCertificateKeyFile /etc/apache2/ssl/${DOMAIN_NAME}/${DOMAIN_NAME}.key
    
    # Logging
    ErrorLog \${APACHE_LOG_DIR}/${APACHE_CONFIG_NAME}_ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/${APACHE_CONFIG_NAME}_ssl_access.log combined
    
    # Redirect root to pgadmin4
    # Note: pgAdmin is served by WSGI at /pgadmin4 (configured in /etc/apache2/conf-enabled/pgadmin4.conf)
    # No proxy needed - WSGI handles it directly on the same Apache instance
    RedirectMatch ^/\$ /pgadmin4/
    
    # Security Headers
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
</VirtualHost>
EOF
    else
        # HTTP only configuration
        cat >> "${vhost_config}" <<EOF
    # Redirect root to pgadmin4
    # Note: pgAdmin is served by WSGI at /pgadmin4 (configured in /etc/apache2/conf-enabled/pgadmin4.conf)
    # No proxy needed - WSGI handles it directly on the same Apache instance
    RedirectMatch ^/\$ /pgadmin4/
    
    # Security Headers
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
</VirtualHost>
EOF
    fi
    
    VHOST_CREATED=true
    log_success "VirtualHost configuration created: ${vhost_config}"
}

# =============================================================================
# VirtualHost Enablement
# =============================================================================

enable_vhost() {
    log_info "Enabling VirtualHost configuration..."
    
    # Enable the site
    a2ensite "${APACHE_CONFIG_NAME}" > /dev/null 2>&1
    log_success "VirtualHost site enabled"
    
    # Test Apache configuration
    log_info "Testing Apache configuration..."
    if apache2ctl configtest > /dev/null 2>&1; then
        log_success "Apache configuration test passed"
    else
        log_error "Apache configuration test failed"
        apache2ctl configtest
        exit 1
    fi
    
    # Reload Apache
    log_info "Reloading Apache..."
    systemctl reload apache2
    log_success "Apache reloaded successfully"
}

# =============================================================================
# Hosts File Configuration
# =============================================================================

configure_hosts_file() {
    log_info "Configuring /etc/hosts..."
    
    # Check if entry already exists
    if grep -q "^127.0.0.1[[:space:]].*${DOMAIN_NAME}" /etc/hosts; then
        log_warning "Entry for ${DOMAIN_NAME} already exists in /etc/hosts"
        log_info "Skipping /etc/hosts modification"
        return 0
    fi
    
    # Add entry to /etc/hosts
    echo "127.0.0.1    ${DOMAIN_NAME}" >> /etc/hosts
    HOSTS_MODIFIED=true
    log_success "Added ${DOMAIN_NAME} to /etc/hosts"
}

# =============================================================================
# Verification Functions
# =============================================================================

verify_proxy() {
    log_info "Verifying domain configuration..."
    
    # Wait a moment for Apache to fully reload
    sleep 2
    
    # Test HTTP connectivity
    log_info "Testing HTTP connectivity..."
    if curl -s -o /dev/null -w "%{http_code}" --max-time "${VERIFY_TIMEOUT:-10}" "http://${DOMAIN_NAME}/" | grep -q -E "^(200|302|301)$"; then
        log_success "HTTP connectivity test passed"
    else
        log_warning "HTTP connectivity test failed (this may be expected if SSL redirect is configured)"
    fi
    
    # Test HTTPS connectivity if SSL is enabled
    if [ "${ENABLE_SSL}" = "yes" ]; then
        log_info "Testing HTTPS connectivity..."
        if curl -k -s -o /dev/null -w "%{http_code}" --max-time "${VERIFY_TIMEOUT:-10}" "https://${DOMAIN_NAME}/" | grep -q -E "^(200|302)$"; then
            log_success "HTTPS connectivity test passed"
        else
            log_error "HTTPS connectivity test failed"
            exit 1
        fi
    fi
    
    log_success "Domain configuration verification completed successfully"
}

# =============================================================================
# Connection Information Display
# =============================================================================

display_connection_info() {
    echo ""
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}        Apache Domain Configuration Completed Successfully!${NC}"
    echo -e "${GREEN}=============================================================================${NC}"
    echo ""
    
    echo -e "${BLUE}Access Information:${NC}"
    echo "-------------------------------------------"
    
    if [ "${ENABLE_SSL}" = "yes" ]; then
        echo -e "🌐 pgAdmin URL: ${GREEN}https://${DOMAIN_NAME}/${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  Certificate Warning:${NC}"
        echo "   Your browser will show a security warning because we're using a"
        echo "   self-signed certificate. This is normal for local development."
        echo "   Click 'Advanced' or 'Proceed' to continue."
    else
        echo -e "🌐 pgAdmin URL: ${GREEN}http://${DOMAIN_NAME}/${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Configuration Details:${NC}"
    echo "-------------------------------------------"
    echo "Domain Name: ${DOMAIN_NAME}"
    echo "pgAdmin Path: /pgadmin4/ (served via WSGI)"
    echo "SSL Enabled: ${ENABLE_SSL}"
    
    if [ "${ENABLE_SSL}" = "yes" ]; then
        echo "Certificate: /etc/apache2/ssl/${DOMAIN_NAME}/${DOMAIN_NAME}.crt"
        echo "Private Key: /etc/apache2/ssl/${DOMAIN_NAME}/${DOMAIN_NAME}.key"
    fi
    
    echo "Apache Config: /etc/apache2/sites-available/${APACHE_CONFIG_NAME}.conf"
    echo ""
    
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "-------------------------------------------"
    echo "Check Apache status:  systemctl status apache2"
    echo "Restart Apache:       systemctl restart apache2"
    echo "View Apache logs:     tail -f /var/log/apache2/${APACHE_CONFIG_NAME}_*.log"
    local scheme="http"
    local curl_opts="-I"
    if [ "${ENABLE_SSL:-no}" = "yes" ]; then
        scheme="https"
        curl_opts="-kI"
    fi
    echo "Test connectivity:    curl ${curl_opts} ${scheme}://${DOMAIN_NAME}/"
    echo "Edit VirtualHost:     nano /etc/apache2/sites-available/${APACHE_CONFIG_NAME}.conf"
    echo ""
    
    echo -e "${BLUE}Backup Location:${NC}"
    echo "-------------------------------------------"
    echo "${BACKUP_DIR}"
    echo ""
    
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}Enjoy using pgAdmin with your custom domain!${NC}"
    echo -e "${GREEN}=============================================================================${NC}"
    echo ""
}

# =============================================================================
# Cleanup and Rollback Functions
# =============================================================================

cleanup_on_error() {
    # Disable ERR trap and 'set -e' to avoid recursive error handling
    # or aborting in the middle of rollback/cleanup.
    trap - ERR
    set +e
    
    log_error "An error occurred during installation"
    
    if [ "$INSTALLATION_STARTED" = true ]; then
        log_info "Starting rollback process..."
        rollback_installation || log_error "Rollback encountered errors; manual intervention may be required."
    fi
    
    log_error "Installation failed. Check the log file for details: ${LOG_FILE}"
    exit 1
}

rollback_installation() {
    log_warning "Rolling back installation changes..."
    
    # Disable and remove VirtualHost if created
    if [ "$VHOST_CREATED" = true ]; then
        log_info "Disabling VirtualHost..."
        a2dissite "${APACHE_CONFIG_NAME}" > /dev/null 2>&1 || true
        
        log_info "Removing VirtualHost configuration..."
        rm -f "/etc/apache2/sites-available/${APACHE_CONFIG_NAME}.conf"
    fi
    
    # Restore /etc/hosts if modified
    if [ "$HOSTS_MODIFIED" = true ] && [ -n "${BACKUP_DIR}" ] && [ -f "${BACKUP_DIR}/hosts.backup" ]; then
        log_info "Restoring /etc/hosts..."
        cp "${BACKUP_DIR}/hosts.backup" /etc/hosts
    fi
    
    # Remove SSL certificates if created
    if [ "$SSL_CONFIGURED" = true ]; then
        log_info "Removing SSL certificates..."
        rm -rf "/etc/apache2/ssl/${DOMAIN_NAME}"
    fi
    
    # Reload Apache
    log_info "Reloading Apache..."
    systemctl reload apache2 2>/dev/null || true
    
    log_success "Rollback completed"
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Display banner
    display_banner
    
    # Set up error trap (will be activated after INSTALLATION_STARTED=true)
    trap cleanup_on_error ERR
    
    # Pre-flight checks
    check_root
    check_ubuntu_version
    check_apache_exists
    check_pgadmin_exists
    
    # Load and validate configuration
    load_config
    
    # Create backup
    create_backup
    
    # Mark installation as started (enables rollback on error)
    INSTALLATION_STARTED=true
    log_info "Installation started - automatic rollback enabled on errors"
    
    # Enable Apache modules
    enable_apache_modules
    
    # Generate SSL certificate if needed
    generate_ssl_certificate
    
    # Create VirtualHost configuration
    create_vhost_config
    
    # Enable VirtualHost
    enable_vhost
    
    # Configure /etc/hosts
    configure_hosts_file
    
    # Verify installation
    verify_proxy
    
    # Display connection information
    display_connection_info
    
    log_success "Apache domain configuration completed successfully!"
}

# =============================================================================
# Script Entry Point
# =============================================================================

main "$@"
