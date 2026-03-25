#!/bin/bash

###############################################################################
# pgAdmin Upgrade Script for Ubuntu 24.04
# 
# This script automates the upgrade of pgAdmin4 Web while preserving:
#   - Apache VirtualHost configurations
#   - WSGI settings
#   - SSL certificates
#   - pgAdmin user data (server connections, preferences)
#   - Custom domain configurations
#
# Usage: sudo ./upgrade_pgadmin.sh
# 
# Requirements:
#   - Ubuntu 24.04 LTS (recommended)
#   - Root/sudo privileges
#   - Existing pgAdmin4 installation
#   - Configured upgrade_pgadmin_config.conf file
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# ====================
# Global Variables
# ====================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/upgrade_pgadmin_config.conf"
BACKUP_DIR=""
UPGRADE_STARTED=false
PACKAGE_UPGRADED=false
OLD_VERSION=""
NEW_VERSION=""

# ====================
# Color Codes for Output
# ====================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ====================
# Logging Functions
# ====================

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - ${message}" >> "${LOG_FILE:-/tmp/upgrade_pgadmin.log}"
}

log_info() {
    log "[INFO] $1"
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "[SUCCESS] $1"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "[WARNING] $1"
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "[ERROR] $1"
    echo -e "${RED}[ERROR]${NC} $1"
}

# ====================
# Banner Display
# ====================

display_banner() {
    echo -e "${GREEN}"
    echo "============================================================================="
    echo "                    pgAdmin Upgrade Script"
    echo "============================================================================="
    echo -e "${NC}"
    log_info "Starting pgAdmin upgrade process..."
}

# ====================
# Error Handler and Cleanup
# ====================

cleanup_on_error() {
    local exit_code=$?
    
    # Disable ERR trap and 'set -e' to avoid recursive error handling
    # or aborting in the middle of rollback/cleanup.
    trap - ERR
    set +e
    
    log_error "Script failed with exit code: ${exit_code}"
    
    if [ "$UPGRADE_STARTED" = true ]; then
        if [ "${AUTO_ROLLBACK_ON_FAILURE:-yes}" = "yes" ]; then
            log_warning "Attempting automatic rollback..."
            rollback_upgrade || log_error "Automatic rollback encountered errors; manual intervention may be required."
        else
            log_warning "Automatic rollback is disabled"
            log_error "Backup location: ${BACKUP_DIR}"
            log_error "To rollback manually, run: sudo ./upgrade_pgadmin.sh --rollback"
        fi
    fi
    
    log_error "Upgrade failed. Check log file: ${LOG_FILE}"
    exit "${exit_code}"
}

# ====================
# Pre-flight Checks
# ====================

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

check_pgadmin_exists() {
    log_info "Checking if pgAdmin4 is installed..."

    # Use dpkg-query to reliably check that pgadmin4-web is actually installed
    # and avoid false positives from residual configs or partial states.
    local pgadmin_status
    pgadmin_status=$(dpkg-query -W -f='${Status}' pgadmin4-web 2>/dev/null || true)

    if [ "$pgadmin_status" != "install ok installed" ]; then
        log_error "pgAdmin4-web is not installed!"
        log_error "This script is for upgrading existing installations only."
        log_error "To install pgAdmin, run: sudo ./install_postgresql_pgadmin.sh"
        exit 1
    fi
    log_success "pgAdmin4-web is installed"
}

check_apache_running() {
    log_info "Checking if Apache is running..."
    
    if ! systemctl is-active --quiet apache2; then
        log_error "Apache is not running!"
        log_error "Please start Apache before upgrading: sudo systemctl start apache2"
        exit 1
    fi
    
    log_success "Apache is running"
}

get_current_version() {
    log_info "Detecting current pgAdmin version..."
    
    OLD_VERSION=$(dpkg -l | grep pgadmin4-web | awk '{print $3}' | head -1)
    
    if [ -z "$OLD_VERSION" ]; then
        log_error "Unable to detect current pgAdmin version"
        exit 1
    fi
    
    log_success "Current pgAdmin version: ${OLD_VERSION}"
    
    # Extract major version for comparison
    local major_version=$(echo "$OLD_VERSION" | cut -d. -f1)
    export OLD_MAJOR_VERSION=$major_version
}

extract_version_from_backup() {
    log_info "Extracting version information from backup..."
    
    local state_file="${BACKUP_DIR}/system_state.txt"
    
    if [ ! -f "$state_file" ]; then
        log_error "System state file not found in backup: ${state_file}"
        log_error "Cannot determine previous version for package downgrade"
        return 1
    fi
    
    # Extract old version from system_state.txt
    OLD_VERSION=$(grep "^Old Version:" "$state_file" | awk '{print $3}')
    
    if [ -z "$OLD_VERSION" ]; then
        log_error "Unable to extract old version from backup"
        log_error "Manual package downgrade may be required"
        return 1
    fi
    
    log_success "Extracted version from backup: ${OLD_VERSION}"
    return 0
}

check_version_availability() {
    log_info "Checking if target version is available..."
    
    # Update package lists first
    apt-get update -qq
    
    if [ "$TARGET_VERSION" = "latest" ]; then
        # Check what the latest version would be
        local available_version=$(apt-cache policy pgadmin4-web | grep Candidate | awk '{print $2}')
        
        if [ -z "$available_version" ]; then
            log_error "Unable to determine latest available version"
            exit 1
        fi
        
        log_info "Latest available version: ${available_version}"
        
        # Check if we're already on the latest version
        if [ "$OLD_VERSION" = "$available_version" ] && [ "${FORCE_UPGRADE:-no}" != "yes" ]; then
            log_warning "Already running the latest version (${OLD_VERSION})"
            log_info "Use FORCE_UPGRADE=yes in config to force reinstall"
            exit 0
        fi
        
        NEW_VERSION="$available_version"
    else
        # Resolve target version to full APT version string
        # This allows users to specify short forms like "9.13" which will match "9.13-1"
        local resolved_version=$(apt-cache policy pgadmin4-web | grep -oP "^\s+\K${TARGET_VERSION}[^\s]*" | head -n 1)
        
        if [ -z "$resolved_version" ]; then
            log_error "Version matching ${TARGET_VERSION} not found in repository"
            log_info "Available versions:"
            apt-cache policy pgadmin4-web | grep -A 20 "Version table"
            exit 1
        fi
        
        NEW_VERSION="$resolved_version"
        log_info "Resolved ${TARGET_VERSION} to full version: ${NEW_VERSION}"
        
        # Check if we're already on this version
        if [ "$OLD_VERSION" = "$NEW_VERSION" ] && [ "${FORCE_UPGRADE:-no}" != "yes" ]; then
            log_warning "Already running version ${OLD_VERSION}"
            log_info "Use FORCE_UPGRADE=yes in config to force reinstall"
            exit 0
        fi
    fi
    
    # Check for major version changes
    local new_major_version=$(echo "$NEW_VERSION" | cut -d. -f1)
    if [ "$OLD_MAJOR_VERSION" != "$new_major_version" ]; then
        log_warning "========================================================"
        log_warning "MAJOR VERSION UPGRADE DETECTED"
        log_warning "Upgrading from version $OLD_MAJOR_VERSION.x to $new_major_version.x"
        log_warning "Major version upgrades may introduce breaking changes."
        log_warning "Please review release notes before proceeding."
        log_warning "========================================================"
        
        if [ "${DRY_RUN:-no}" != "yes" ]; then
            read -p "Continue with major version upgrade? (yes/no): " -r
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                log_info "Upgrade cancelled by user"
                exit 0
            fi
        fi
    fi
    
    log_success "Target version ${NEW_VERSION} is available"
}

# ====================
# Configuration Loading
# ====================

load_config() {
    # Save current log file (temp) so config file doesn't overwrite it
    local temp_log_file="${LOG_FILE}"
    
    log_info "Loading configuration from ${CONFIG_FILE}..."
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        exit 1
    fi
    
    # Source the configuration file
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
    
    # Save configured log path, then restore temp log for now
    CONFIGURED_LOG_FILE="${LOG_FILE}"
    LOG_FILE="${temp_log_file}"
    
    log_success "Configuration loaded successfully"
    
    # Validate required variables
    log_info "Validating configuration..."
    
    if [ -z "${TARGET_VERSION:-}" ]; then
        log_error "TARGET_VERSION is not set in configuration file"
        exit 1
    fi
    
    if [ -z "${BACKUP_BASE_DIR:-}" ]; then
        log_error "BACKUP_BASE_DIR is not set in configuration file"
        exit 1
    fi
    
    # Validate boolean options
    for var in PRESERVE_USER_DATA AUTO_ROLLBACK_ON_FAILURE DRY_RUN BACKUP_APACHE_CONFIGS BACKUP_SSL_CERTS SKIP_PREFLIGHT_CHECKS TEST_HTTPS FORCE_UPGRADE; do
        local value="${!var:-}"
        if [ "$value" != "yes" ] && [ "$value" != "no" ]; then
            log_error "${var} must be 'yes' or 'no', got: ${value}"
            exit 1
        fi
    done
    
    # Validate numeric options
    if [ -n "${VERIFY_TIMEOUT:-}" ]; then
        if ! [[ "${VERIFY_TIMEOUT}" =~ ^[0-9]+$ ]]; then
            log_error "VERIFY_TIMEOUT must be a positive integer, got: ${VERIFY_TIMEOUT}"
            exit 1
        fi
    fi
    
    log_success "Configuration validated successfully"
    log_info "Target Version: ${TARGET_VERSION}"
    log_info "Preserve User Data: ${PRESERVE_USER_DATA}"
    log_info "Dry Run Mode: ${DRY_RUN}"
}

# ====================
# Backup Functions
# ====================

backup_configurations() {
    log_info "Creating comprehensive backup of configurations..."
    
    BACKUP_DIR="${BACKUP_BASE_DIR}_$(date +%Y%m%d_%H%M%S)"
    # Create backup directory with restrictive permissions to protect sensitive pgAdmin data
    local original_umask
    original_umask=$(umask)
    umask 077
    mkdir -p "${BACKUP_DIR}"
    umask "${original_umask}"
    chmod 700 "${BACKUP_DIR}"
    
    log_info "Backup directory: ${BACKUP_DIR}"
    
    # Backup pgAdmin package configuration
    if [ -d /etc/pgadmin ]; then
        log_info "Backing up /etc/pgadmin/..."
        cp -r /etc/pgadmin "${BACKUP_DIR}/etc_pgadmin"
        log_success "pgAdmin configuration backed up"
    else
        log_warning "/etc/pgadmin does not exist, skipping"
    fi
    
    # Backup pgAdmin user data
    if [ "${PRESERVE_USER_DATA}" = "yes" ]; then
        if [ -d /var/lib/pgadmin ]; then
            log_info "Backing up /var/lib/pgadmin/..."
            cp -r /var/lib/pgadmin "${BACKUP_DIR}/var_lib_pgadmin"
            log_success "pgAdmin user data backed up"
        else
            log_warning "/var/lib/pgadmin does not exist, skipping"
        fi
    else
        log_info "User data preservation is disabled, skipping backup"
    fi
    
    # Backup Apache configurations
    if [ "${BACKUP_APACHE_CONFIGS}" = "yes" ]; then
        log_info "Backing up Apache configurations..."
        mkdir -p "${BACKUP_DIR}/apache"
        
        # Backup pgAdmin WSGI config
        if [ -f /etc/apache2/conf-available/pgadmin4.conf ]; then
            cp /etc/apache2/conf-available/pgadmin4.conf "${BACKUP_DIR}/apache/pgadmin4.conf"
            log_success "Backed up pgAdmin WSGI configuration"
        fi
        
        # Backup all VirtualHost configs that might reference pgadmin
        log_info "Searching for VirtualHost configs referencing pgadmin..."
        local vhost_count=0
        for vhost in /etc/apache2/sites-available/*.conf; do
            if [ -f "$vhost" ] && grep -q "pgadmin" "$vhost"; then
                cp "$vhost" "${BACKUP_DIR}/apache/$(basename "$vhost")"
                vhost_count=$((vhost_count + 1))
                log_info "Backed up: $(basename "$vhost")"
            fi
        done
        
        if [ $vhost_count -eq 0 ]; then
            log_warning "No VirtualHost configs referencing pgadmin found"
        else
            log_success "Backed up ${vhost_count} VirtualHost configuration(s)"
        fi
        
        # Save list of enabled sites
        ls -l /etc/apache2/sites-enabled/ > "${BACKUP_DIR}/apache/sites_enabled_list.txt"
        log_success "Saved list of enabled Apache sites"
        
        # Save Apache module list
        apache2ctl -M > "${BACKUP_DIR}/apache/modules_enabled.txt" 2>&1
        log_success "Saved Apache module list"
    fi
    
    # Backup SSL certificates
    if [ "${BACKUP_SSL_CERTS}" = "yes" ]; then
        if [ -d /etc/apache2/ssl ]; then
            log_info "Backing up SSL certificates..."
            cp -r /etc/apache2/ssl "${BACKUP_DIR}/apache_ssl"
            log_success "SSL certificates backed up"
        else
            log_info "No SSL certificates found at /etc/apache2/ssl"
        fi
    fi
    
    # Save current system state
    log_info "Saving system state information..."
    {
        echo "=== Upgrade Information ==="
        echo "Date: $(date)"
        echo "Old Version: ${OLD_VERSION}"
        echo "Target Version: ${TARGET_VERSION}"
        echo "New Version: ${NEW_VERSION}"
        echo ""
        echo "=== Package Information ==="
        dpkg -l | grep pgadmin
        echo ""
        echo "=== Apache Status ==="
        systemctl status apache2 --no-pager
    } > "${BACKUP_DIR}/system_state.txt"
    
    log_success "Backup completed successfully"
    log_info "Backup location: ${BACKUP_DIR}"
}

# ====================
# Upgrade Functions
# ====================

upgrade_pgadmin_package() {
    log_info "Starting pgAdmin upgrade process..."
    
    if [ "${DRY_RUN}" = "yes" ]; then
        log_warning "DRY RUN MODE: Skipping actual upgrade"
        log_info "Would upgrade pgAdmin from ${OLD_VERSION} to ${NEW_VERSION}"
        return 0
    fi
    
    # Update package lists
    log_info "Updating package lists..."
    apt-get update
    
    # Perform upgrade
    if [ "$TARGET_VERSION" = "latest" ]; then
        log_info "Upgrading pgAdmin to latest version..."
        apt-get install -y --only-upgrade pgadmin4-web
    else
        log_info "Installing pgAdmin version ${NEW_VERSION}..."
        apt-get install -y pgadmin4-web="${NEW_VERSION}"
    fi
    
    PACKAGE_UPGRADED=true
    
    log_success "pgAdmin package upgrade completed"
    
    # Verify new version
    local installed_version=$(dpkg -l | grep pgadmin4-web | awk '{print $3}' | head -1)
    log_info "Installed version: ${installed_version}"
    
    if [ "$installed_version" != "$NEW_VERSION" ] && [ "$TARGET_VERSION" != "latest" ]; then
        log_warning "Installed version (${installed_version}) does not match target (${NEW_VERSION})"
    fi
}

# ====================
# Verification Functions
# ====================

verify_upgrade() {
    log_info "Verifying upgrade..."
    
    # Check Apache status
    log_info "Checking Apache service status..."
    if systemctl is-active --quiet apache2; then
        log_success "✓ Apache service is running"
    else
        log_error "✗ Apache service is not running"
        return 1
    fi
    
    # Check pgAdmin WSGI configuration
    log_info "Checking pgAdmin WSGI configuration..."
    if [ -f /etc/apache2/conf-enabled/pgadmin4.conf ]; then
        log_success "✓ pgAdmin WSGI configuration is present"
    else
        log_error "✗ pgAdmin WSGI configuration is missing"
        return 1
    fi
    
    # Check basic connectivity
    log_info "Testing pgAdmin HTTP connectivity..."
    local timeout="${VERIFY_TIMEOUT:-10}"
    
    if curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "http://127.0.0.1/pgadmin4/" | grep -q -E "^(200|302)$"; then
        log_success "✓ pgAdmin is accessible at http://127.0.0.1/pgadmin4/"
    else
        log_error "✗ Cannot access pgAdmin at http://127.0.0.1/pgadmin4/"
        return 1
    fi
    
    # Test custom domain if configured
    if [ -n "${CUSTOM_DOMAIN:-}" ]; then
        log_info "Testing custom domain: ${CUSTOM_DOMAIN}..."
        
        if curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "http://${CUSTOM_DOMAIN}/" | grep -q -E "^(200|302|301)$"; then
            log_success "✓ Custom domain is accessible"
        else
            log_warning "⚠ Custom domain test failed (may be expected)"
        fi
        
        # Test HTTPS if configured
        if [ "${TEST_HTTPS:-no}" = "yes" ]; then
            log_info "Testing HTTPS connectivity..."
            local https_code=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "https://${CUSTOM_DOMAIN}/")
            
            if echo "$https_code" | grep -q -E "^(200|302|301)$"; then
                log_success "✓ HTTPS is working (HTTP $https_code)"
            else
                # Fallback: test /pgadmin4/ path explicitly
                log_info "Testing HTTPS with /pgadmin4/ path..."
                if curl -k -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "https://${CUSTOM_DOMAIN}/pgadmin4/" | grep -q -E "^(200|302)$"; then
                    log_success "✓ HTTPS is working at /pgadmin4/"
                else
                    log_warning "⚠ HTTPS test failed"
                fi
            fi
        fi
    fi
    
    log_success "All verification checks passed"
}

verify_pgadmin_data() {
    log_info "Verifying pgAdmin user data..."
    
    # Check storage directory
    if [ -d /var/lib/pgadmin/storage ]; then
        if [ -w /var/lib/pgadmin/storage ]; then
            log_success "✓ pgAdmin storage directory is writable"
        else
            log_warning "⚠ pgAdmin storage directory is not writable"
        fi
    else
        log_warning "⚠ pgAdmin storage directory does not exist"
    fi
    
    # Check pgAdmin database
    if [ -f /var/lib/pgadmin/pgadmin4.db ]; then
        log_success "✓ pgAdmin database file exists"
    else
        log_warning "⚠ pgAdmin database file not found"
    fi
    
    log_success "User data verification completed"
}

# ====================
# Rollback Functions
# ====================

rollback_upgrade() {
    log_warning "Starting rollback process..."
    
    if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
        log_error "Backup directory not found, cannot rollback"
        log_error "Manual intervention required"
        return 1
    fi
    
    if [ "${DRY_RUN}" = "yes" ]; then
        log_warning "DRY RUN MODE: Skipping actual rollback"
        return 0
    fi
    
    # Stop Apache
    log_info "Stopping Apache..."
    systemctl stop apache2 || true
    
    # Downgrade pgAdmin if package was upgraded
    if [ "$PACKAGE_UPGRADED" = true ] && [ -n "$OLD_VERSION" ]; then
        log_info "Downgrading pgAdmin to version ${OLD_VERSION}..."
        apt-get install -y --allow-downgrades pgadmin4-web="${OLD_VERSION}" || {
            log_error "Failed to downgrade pgAdmin package"
            log_warning "Attempting to restore configurations anyway..."
        }
    fi
    
    # Restore pgAdmin configuration
    if [ -d "${BACKUP_DIR}/etc_pgadmin" ]; then
        log_info "Restoring pgAdmin configuration..."
        rm -rf /etc/pgadmin
        cp -r "${BACKUP_DIR}/etc_pgadmin" /etc/pgadmin
        log_success "pgAdmin configuration restored"
    fi
    
    # Restore user data if it was backed up
    if [ -d "${BACKUP_DIR}/var_lib_pgadmin" ]; then
        log_info "Restoring pgAdmin user data..."
        rm -rf /var/lib/pgadmin
        cp -r "${BACKUP_DIR}/var_lib_pgadmin" /var/lib/pgadmin
        # Fix permissions
        chown -R www-data:www-data /var/lib/pgadmin 2>/dev/null || true
        log_success "pgAdmin user data restored"
    fi
    
    # Restore Apache configurations
    if [ -d "${BACKUP_DIR}/apache" ]; then
        log_info "Restoring Apache configurations..."
        
        if [ -f "${BACKUP_DIR}/apache/pgadmin4.conf" ]; then
            cp "${BACKUP_DIR}/apache/pgadmin4.conf" /etc/apache2/conf-available/pgadmin4.conf
            log_success "Restored pgAdmin WSGI configuration"
        fi
        
        # Restore VirtualHost configs (exclude WSGI pgadmin4.conf)
        for vhost in "${BACKUP_DIR}"/apache/*.conf; do
            if [ -f "$vhost" ]; then
                vhost_basename="$(basename "$vhost")"
                # Skip the WSGI config, which is restored separately to conf-available
                if [ "$vhost_basename" = "pgadmin4.conf" ]; then
                    continue
                fi
                cp "$vhost" /etc/apache2/sites-available/
                log_info "Restored: $vhost_basename"
            fi
        done
    fi
    
    # Restore SSL certificates
    if [ -d "${BACKUP_DIR}/apache_ssl" ]; then
        log_info "Restoring SSL certificates..."
        rm -rf /etc/apache2/ssl
        cp -r "${BACKUP_DIR}/apache_ssl" /etc/apache2/ssl
        log_success "SSL certificates restored"
    fi
    
    # Restart Apache
    log_info "Starting Apache..."
    systemctl start apache2
    
    if systemctl is-active --quiet apache2; then
        log_success "Apache restarted successfully"
    else
        log_error "Failed to restart Apache"
        return 1
    fi
    
    # Verify rollback
    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://127.0.0.1/pgadmin4/" | grep -q -E "^(200|302)$"; then
        log_success "✓ pgAdmin is accessible after rollback"
    else
        log_error "✗ pgAdmin is not accessible after rollback"
        return 1
    fi
    
    log_success "Rollback completed successfully"
    log_info "Restored to version: ${OLD_VERSION}"
}

# ====================
# Summary Display
# ====================

display_summary() {
    echo ""
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}                pgAdmin Upgrade Completed Successfully!${NC}"
    echo -e "${GREEN}=============================================================================${NC}"
    echo ""
    
    echo -e "${BLUE}Upgrade Summary:${NC}"
    echo "-------------------------------------------"
    echo -e "Previous Version: ${YELLOW}${OLD_VERSION}${NC}"
    echo -e "New Version:      ${GREEN}${NEW_VERSION}${NC}"
    echo ""
    
    echo -e "${BLUE}What Was Preserved:${NC}"
    echo "-------------------------------------------"
    echo "✓ Apache VirtualHost configurations"
    echo "✓ pgAdmin WSGI settings"
    echo "✓ SSL certificates"
    if [ "${PRESERVE_USER_DATA}" = "yes" ]; then
        echo "✓ pgAdmin user data (server connections, preferences)"
    fi
    echo ""
    
    echo -e "${BLUE}Access Information:${NC}"
    echo "-------------------------------------------"
    echo "Default URL: http://localhost/pgadmin4/"
    if [ -n "${CUSTOM_DOMAIN:-}" ]; then
        local scheme="http"
        if [ "${TEST_HTTPS:-no}" = "yes" ]; then
            scheme="https"
        fi
        echo "Custom Domain: ${scheme}://${CUSTOM_DOMAIN}/"
    fi
    echo ""
    
    echo -e "${BLUE}Backup Location:${NC}"
    echo "-------------------------------------------"
    echo "${BACKUP_DIR}"
    echo ""
    
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "-------------------------------------------"
    echo "Check pgAdmin status:  systemctl status apache2"
    echo "View upgrade log:      cat ${LOG_FILE}"
    echo "Test connectivity:     curl -I http://localhost/pgadmin4/"
    echo ""
    
    if [ "${DRY_RUN}" = "yes" ]; then
        echo -e "${YELLOW}=============================================================================${NC}"
        echo -e "${YELLOW}                    DRY RUN MODE - NO CHANGES MADE${NC}"
        echo -e "${YELLOW}=============================================================================${NC}"
        echo ""
    fi
    
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}Enjoy using the upgraded pgAdmin!${NC}"
    echo -e "${GREEN}=============================================================================${NC}"
    echo ""
}

# ====================
# Main Function
# ====================

main() {
    # Display banner
    display_banner
    
    # Set up error trap
    trap cleanup_on_error ERR
    
    log_info "Temporary log file: ${LOG_FILE}"
    
    # Load configuration
    load_config
    
    # Migrate to configured log file (after config is loaded)
    if [ -n "${CONFIGURED_LOG_FILE:-}" ]; then
        local temp_log="${LOG_FILE}"
        local configured_log="${CONFIGURED_LOG_FILE}"
        local log_dir="$(dirname "${configured_log}")"
        
        # Ensure log directory exists and is writable
        if [ ! -d "${log_dir}" ]; then
            if ! mkdir -p "${log_dir}" 2>/dev/null; then
                log_warning "Cannot create log directory: ${log_dir}"
                log_warning "Continuing with temporary log file: ${temp_log}"
            fi
        fi
        
        # Test if we can write to the configured log location
        if [ ! -d "${log_dir}" ] || ! touch "${configured_log}" 2>/dev/null; then
            log_warning "Cannot write to configured log file: ${configured_log}"
            log_warning "Continuing with temporary log file: ${temp_log}"
        else
            # Copy temp log to configured location
            if [ -f "${temp_log}" ]; then
                cat "${temp_log}" > "${configured_log}" 2>/dev/null || true
            fi
            LOG_FILE="${configured_log}"
            log_info "Log file set to: ${LOG_FILE}"
        fi
    fi
    
    # Always enforce root/sudo privileges
    check_root
    
    # Pre-flight checks (can be partially skipped)
    if [ "${SKIP_PREFLIGHT_CHECKS:-no}" != "yes" ]; then
        check_ubuntu_version
        check_pgadmin_exists
        check_apache_running
        get_current_version
        check_version_availability
    else
        log_warning "Skipping pre-flight checks as requested"
        # Still determine versions to ensure upgrade logic has required data
        get_current_version
        check_version_availability
    fi
    
    # Create backup
    backup_configurations
    
    # Mark upgrade as started (enables automatic rollback on error)
    UPGRADE_STARTED=true
    log_info "Upgrade started - automatic rollback enabled on errors"
    
    # Perform upgrade
    upgrade_pgadmin_package
    
    # Verify upgrade
    verify_upgrade
    verify_pgadmin_data
    
    # Display summary
    display_summary
    
    log_success "pgAdmin upgrade completed successfully!"
}

# ====================
# Script Entry Point
# ====================

# Initialize logging early (before any log calls)
LOG_FILE="$(mktemp -t pgadmin_upgrade_XXXXXX.log)"

# Handle command-line arguments
if [ $# -gt 0 ]; then
    case "$1" in
        --rollback)
            log_info "Manual rollback requested"
            check_root
            if [ -z "${2:-}" ]; then
                log_error "Please specify backup directory"
                log_error "Usage: sudo ./upgrade_pgadmin.sh --rollback /path/to/backup"
                exit 1
            fi
            BACKUP_DIR="$2"
            load_config
            
            # Migrate to configured log file
            if [ -n "${CONFIGURED_LOG_FILE:-}" ]; then
                temp_log="${LOG_FILE}"
                configured_log="${CONFIGURED_LOG_FILE}"
                log_dir="$(dirname "${configured_log}")"
                
                if [ ! -d "${log_dir}" ]; then
                    mkdir -p "${log_dir}" 2>/dev/null || true
                fi
                
                if [ -d "${log_dir}" ] && touch "${configured_log}" 2>/dev/null; then
                    [ -f "${temp_log}" ] && cat "${temp_log}" > "${configured_log}" 2>/dev/null || true
                    LOG_FILE="${configured_log}"
                else
                    log_warning "Cannot write to configured log file: ${configured_log}"
                    LOG_FILE="${temp_log}"
                    log_warning "Continuing with temporary log file: ${temp_log}"
                fi
            fi
            
            # Extract OLD_VERSION from backup before rollback
            if extract_version_from_backup && [ -n "${OLD_VERSION}" ]; then
                # Mark package as "upgraded" so rollback_upgrade() will attempt the downgrade
                PACKAGE_UPGRADED=true
            else
                log_warning "Could not extract version from backup"
                log_warning "Package downgrade will be skipped, but configurations will be restored"
            fi
            
            rollback_upgrade
            exit 0
            ;;
        --help|-h)
            echo "Usage: sudo ./upgrade_pgadmin.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --rollback <backup_dir>  Rollback to previous version using specified backup"
            echo "  --help, -h               Show this help message"
            echo ""
            echo "Configuration:"
            echo "  Edit upgrade_pgadmin_config.conf before running"
            echo ""
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            log_error "Use --help for usage information"
            exit 1
            ;;
    esac
fi

main "$@"
