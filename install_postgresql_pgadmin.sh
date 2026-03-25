#!/bin/bash

###############################################################################
# PostgreSQL and pgAdmin4 Installation Script for Ubuntu 24.04
# 
# This script automates the installation and configuration of:
#   - PostgreSQL database server
#   - pgAdmin4 Web interface
#   - Custom database and user creation
#   - Optional remote access configuration
#
# Usage: sudo ./install_postgresql_pgadmin.sh
# 
# Requirements:
#   - Ubuntu 24.04 LTS
#   - Root/sudo privileges
#   - Configured install_config.conf file
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# ====================
# Global Variables
# ====================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/install_config.conf"
BACKUP_DIR="/tmp/postgresql_pgadmin_backup_$(date +%Y%m%d_%H%M%S)"
INSTALLATION_STARTED=false
POSTGRES_INSTALLED=false
PGADMIN_INSTALLED=false

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
    echo -e "${timestamp} - ${message}" | tee -a "${LOG_FILE:-/tmp/install.log}"
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
# Error Handler and Cleanup
# ====================

cleanup_on_error() {
    local exit_code=$?
    
    # Disable ERR trap and 'set -e' to avoid recursive error handling
    # or aborting in the middle of rollback/cleanup.
    trap - ERR
    set +e
    
    log_error "Script failed with exit code: ${exit_code}"
    
    if [ "$INSTALLATION_STARTED" = true ]; then
        log_warning "Attempting rollback..."
        rollback_installation || log_error "Rollback encountered errors; manual intervention may be required."
    fi
    
    log_error "Installation failed. Check log file: ${LOG_FILE}"
    exit "${exit_code}"
}

rollback_installation() {
    log_info "Starting rollback process..."
    
    # Stop services
    if [ "$PGADMIN_INSTALLED" = true ]; then
        log_info "Stopping Apache2 service..."
        systemctl stop apache2 2>/dev/null || true
    fi
    
    if [ "$POSTGRES_INSTALLED" = true ]; then
        log_info "Stopping PostgreSQL service..."
        systemctl stop postgresql 2>/dev/null || true
    fi
    
    # Remove installed packages
    if [ "$PGADMIN_INSTALLED" = true ]; then
        log_info "Removing pgAdmin4..."
        apt-get remove -y pgadmin4 pgadmin4-web 2>/dev/null || true
    fi
    
    if [ "$POSTGRES_INSTALLED" = true ]; then
        log_info "Removing PostgreSQL..."
        apt-get remove -y postgresql postgresql-contrib 2>/dev/null || true
    fi
    
    # Restore backed up configuration files
    if [ -d "$BACKUP_DIR" ]; then
        log_info "Restoring backed up configuration files..."
        if [ -f "${BACKUP_DIR}/pg_hba.conf" ]; then
            cp "${BACKUP_DIR}/pg_hba.conf" "/etc/postgresql/*/main/pg_hba.conf" 2>/dev/null || true
        fi
        if [ -f "${BACKUP_DIR}/postgresql.conf" ]; then
            cp "${BACKUP_DIR}/postgresql.conf" "/etc/postgresql/*/main/postgresql.conf" 2>/dev/null || true
        fi
    fi
    
    log_warning "Rollback completed. System restored to previous state."
}

trap cleanup_on_error ERR

# ====================
# Validation Functions
# ====================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root or with sudo"
        log_info "Usage: sudo $0"
        exit 1
    fi
    log_success "Root privileges confirmed"
}

check_ubuntu_version() {
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot determine OS version"
        exit 1
    fi
    
    source /etc/os-release
    
    if [ "$ID" != "ubuntu" ]; then
        log_error "This script is designed for Ubuntu only. Detected: $ID"
        exit 1
    fi
    
    if [ "$VERSION_ID" != "24.04" ]; then
        log_warning "This script is designed for Ubuntu 24.04. Detected: $VERSION_ID"
        log_warning "Proceeding anyway, but there may be compatibility issues..."
    else
        log_success "Ubuntu 24.04 detected"
    fi
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    log_info "Loading configuration from: $CONFIG_FILE"
    source "$CONFIG_FILE"
    
    # Validate required variables
    if [ -z "${POSTGRES_PASSWORD:-}" ]; then
        log_error "POSTGRES_PASSWORD not set in config file"
        exit 1
    fi
    
    if [ ${#POSTGRES_PASSWORD} -lt 8 ]; then
        log_error "POSTGRES_PASSWORD must be at least 8 characters"
        exit 1
    fi
    
    if [ -z "${PGADMIN_EMAIL:-}" ]; then
        log_error "PGADMIN_EMAIL not set in config file"
        exit 1
    fi
    
    if [ -z "${PGADMIN_PASSWORD:-}" ]; then
        log_error "PGADMIN_PASSWORD not set in config file"
        exit 1
    fi
    
    if [ ${#PGADMIN_PASSWORD} -lt 6 ]; then
        log_error "PGADMIN_PASSWORD must be at least 6 characters"
        exit 1
    fi
    
    log_success "Configuration loaded and validated"
}

check_existing_installations() {
    local has_existing=false
    
    # Check for PostgreSQL
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        log_warning "PostgreSQL service is already running"
        has_existing=true
    elif command -v psql &> /dev/null; then
        log_warning "PostgreSQL client is already installed"
        has_existing=true
    fi
    
    # Check for pgAdmin
    if dpkg -l | grep -q pgadmin4; then
        log_warning "pgAdmin4 is already installed"
        has_existing=true
    fi
    
    if [ "$has_existing" = true ]; then
        log_warning "Existing installations detected. This script may overwrite existing configurations."
        read -p "Do you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Installation cancelled by user"
            exit 0
        fi
    else
        log_success "No existing installations detected"
    fi
}

# ====================
# Performance Tuning Functions
# ====================

detect_system_resources() {
    log_info "Detecting system resources..."
    
    # Get total RAM in MB
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_mb=$((total_ram_kb / 1024))
    local total_ram_gb=$((total_ram_mb / 1024))
    
    # Get CPU cores
    local cpu_cores=$(nproc)
    
    # Detect disk type (SSD vs HDD)
    local disk_type="HDD"
    local root_device=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
    local device_name=$(basename "$root_device")
    
    if [ -f "/sys/block/${device_name}/queue/rotational" ]; then
        local rotational=$(cat "/sys/block/${device_name}/queue/rotational")
        if [ "$rotational" -eq 0 ]; then
            disk_type="SSD"
        fi
    fi
    
    log_info "System resources detected:"
    log_info "  - Total RAM: ${total_ram_gb}GB (${total_ram_mb}MB)"
    log_info "  - CPU Cores: ${cpu_cores}"
    log_info "  - Disk Type: ${disk_type}"
    
    # Export for use in other functions
    export DETECTED_RAM_MB=$total_ram_mb
    export DETECTED_RAM_GB=$total_ram_gb
    export DETECTED_CPU_CORES=$cpu_cores
    export DETECTED_DISK_TYPE=$disk_type
}

calculate_performance_settings() {
    local profile="${1:-auto}"
    
    log_info "Calculating performance settings for profile: ${profile}"
    
    # Detect system resources if not already done
    if [ -z "${DETECTED_RAM_MB:-}" ]; then
        detect_system_resources
    fi
    
    local ram_mb=$DETECTED_RAM_MB
    local cpu_cores=$DETECTED_CPU_CORES
    local disk_type=$DETECTED_DISK_TYPE
    
    case "$profile" in
        "auto")
            # Auto-detect based on RAM
            if [ $ram_mb -lt 2048 ]; then
                log_info "Auto-detected profile: LOW (less than 2GB RAM)"
                calculate_performance_settings "low"
                return
            elif [ $ram_mb -lt 8192 ]; then
                log_info "Auto-detected profile: MEDIUM (2-8GB RAM)"
                calculate_performance_settings "medium"
                return
            else
                log_info "Auto-detected profile: HIGH (8GB+ RAM)"
                calculate_performance_settings "high"
                return
            fi
            ;;
        "low")
            # Settings for 1-2GB RAM systems
            PERF_SHARED_BUFFERS="256MB"
            PERF_EFFECTIVE_CACHE_SIZE="1GB"
            PERF_MAINTENANCE_WORK_MEM="64MB"
            PERF_WORK_MEM="4MB"
            PERF_MAX_CONNECTIONS="100"
            PERF_MAX_WAL_SIZE="1GB"
            PERF_MIN_WAL_SIZE="80MB"
            ;;
        "medium")
            # Settings for 4-8GB RAM systems
            PERF_SHARED_BUFFERS="1GB"
            PERF_EFFECTIVE_CACHE_SIZE="3GB"
            PERF_MAINTENANCE_WORK_MEM="256MB"
            PERF_WORK_MEM="16MB"
            PERF_MAX_CONNECTIONS="200"
            PERF_MAX_WAL_SIZE="2GB"
            PERF_MIN_WAL_SIZE="1GB"
            ;;
        "high")
            # Settings for 16GB+ RAM systems
            local shared_buffers_mb=$((ram_mb / 4))
            local effective_cache_mb=$((ram_mb * 3 / 4))
            
            PERF_SHARED_BUFFERS="${shared_buffers_mb}MB"
            PERF_EFFECTIVE_CACHE_SIZE="${effective_cache_mb}MB"
            PERF_MAINTENANCE_WORK_MEM="512MB"
            PERF_WORK_MEM="32MB"
            PERF_MAX_CONNECTIONS="300"
            PERF_MAX_WAL_SIZE="4GB"
            PERF_MIN_WAL_SIZE="2GB"
            ;;
        "custom")
            # Use custom values from config
            PERF_SHARED_BUFFERS="${CUSTOM_SHARED_BUFFERS:-256MB}"
            PERF_EFFECTIVE_CACHE_SIZE="${CUSTOM_EFFECTIVE_CACHE_SIZE:-1GB}"
            PERF_MAINTENANCE_WORK_MEM="${CUSTOM_MAINTENANCE_WORK_MEM:-64MB}"
            PERF_WORK_MEM="${CUSTOM_WORK_MEM:-4MB}"
            PERF_MAX_CONNECTIONS="${CUSTOM_MAX_CONNECTIONS:-100}"
            PERF_MAX_WAL_SIZE="${CUSTOM_MAX_WAL_SIZE:-1GB}"
            PERF_MIN_WAL_SIZE="${CUSTOM_MIN_WAL_SIZE:-80MB}"
            log_info "Using custom performance settings"
            ;;
        *)
            log_error "Unknown performance profile: ${profile}"
            exit 1
            ;;
    esac
    
    # Common settings
    PERF_CHECKPOINT_COMPLETION_TARGET="${CUSTOM_CHECKPOINT_COMPLETION_TARGET:-0.9}"
    PERF_WAL_BUFFERS="${CUSTOM_WAL_BUFFERS:-16MB}"
    PERF_DEFAULT_STATISTICS_TARGET="${CUSTOM_DEFAULT_STATISTICS_TARGET:-100}"
    
    # Disk-specific settings
    if [ "$disk_type" = "SSD" ]; then
        PERF_RANDOM_PAGE_COST="${CUSTOM_RANDOM_PAGE_COST:-1.1}"
        PERF_EFFECTIVE_IO_CONCURRENCY="${CUSTOM_EFFECTIVE_IO_CONCURRENCY:-200}"
    else
        PERF_RANDOM_PAGE_COST="${CUSTOM_RANDOM_PAGE_COST:-4.0}"
        PERF_EFFECTIVE_IO_CONCURRENCY="${CUSTOM_EFFECTIVE_IO_CONCURRENCY:-2}"
    fi
    
    log_info "Performance settings calculated:"
    log_info "  - shared_buffers: ${PERF_SHARED_BUFFERS}"
    log_info "  - effective_cache_size: ${PERF_EFFECTIVE_CACHE_SIZE}"
    log_info "  - maintenance_work_mem: ${PERF_MAINTENANCE_WORK_MEM}"
    log_info "  - work_mem: ${PERF_WORK_MEM}"
    log_info "  - max_connections: ${PERF_MAX_CONNECTIONS}"
    log_info "  - max_wal_size: ${PERF_MAX_WAL_SIZE}"
    log_info "  - random_page_cost: ${PERF_RANDOM_PAGE_COST}"
    log_info "  - effective_io_concurrency: ${PERF_EFFECTIVE_IO_CONCURRENCY}"
}

apply_performance_tuning() {
    local pg_config_file="$1"
    
    log_info "Applying performance tuning to PostgreSQL configuration..."
    
    # Calculate performance settings
    calculate_performance_settings "${PERFORMANCE_PROFILE:-auto}"
    
    # Apply settings to postgresql.conf
    log_info "Modifying postgresql.conf with performance settings..."
    
    # Helper function to set or update a parameter
    set_pg_param() {
        local param="$1"
        local value="$2"
        local config_file="$3"
        
        if grep -q "^[[:space:]]*${param}[[:space:]]*=" "$config_file"; then
            # Parameter exists, update it
            sed -i "s|^[[:space:]]*${param}[[:space:]]*=.*|${param} = ${value}|" "$config_file"
        elif grep -q "^[[:space:]]*#[[:space:]]*${param}[[:space:]]*=" "$config_file"; then
            # Parameter is commented, uncomment and update
            sed -i "s|^[[:space:]]*#[[:space:]]*${param}[[:space:]]*=.*|${param} = ${value}|" "$config_file"
        else
            # Parameter doesn't exist, add it
            echo "" >> "$config_file"
            echo "# Added by install script for performance tuning" >> "$config_file"
            echo "${param} = ${value}" >> "$config_file"
        fi
    }
    
    # Apply memory settings
    set_pg_param "shared_buffers" "'${PERF_SHARED_BUFFERS}'" "$pg_config_file"
    set_pg_param "effective_cache_size" "'${PERF_EFFECTIVE_CACHE_SIZE}'" "$pg_config_file"
    set_pg_param "maintenance_work_mem" "'${PERF_MAINTENANCE_WORK_MEM}'" "$pg_config_file"
    set_pg_param "work_mem" "'${PERF_WORK_MEM}'" "$pg_config_file"
    
    # Apply connection settings
    set_pg_param "max_connections" "${PERF_MAX_CONNECTIONS}" "$pg_config_file"
    
    # Apply WAL settings
    set_pg_param "max_wal_size" "'${PERF_MAX_WAL_SIZE}'" "$pg_config_file"
    set_pg_param "min_wal_size" "'${PERF_MIN_WAL_SIZE}'" "$pg_config_file"
    set_pg_param "checkpoint_completion_target" "${PERF_CHECKPOINT_COMPLETION_TARGET}" "$pg_config_file"
    set_pg_param "wal_buffers" "'${PERF_WAL_BUFFERS}'" "$pg_config_file"
    
    # Apply query planner settings
    set_pg_param "default_statistics_target" "${PERF_DEFAULT_STATISTICS_TARGET}" "$pg_config_file"
    set_pg_param "random_page_cost" "${PERF_RANDOM_PAGE_COST}" "$pg_config_file"
    set_pg_param "effective_io_concurrency" "${PERF_EFFECTIVE_IO_CONCURRENCY}" "$pg_config_file"
    
    log_success "Performance tuning applied successfully"
}

# ====================
# PostgreSQL Installation
# ====================

install_postgresql() {
    log_info "Starting PostgreSQL installation..."
    
    # Update package lists
    log_info "Updating package lists..."
    apt-get update
    
    # Install PostgreSQL
    log_info "Installing PostgreSQL and contrib packages..."
    if [ -n "${POSTGRES_VERSION:-}" ]; then
        apt-get install -y postgresql-${POSTGRES_VERSION} postgresql-contrib-${POSTGRES_VERSION}
    else
        apt-get install -y postgresql postgresql-contrib
    fi
    
    POSTGRES_INSTALLED=true
    
    # Start and enable PostgreSQL service
    log_info "Starting PostgreSQL service..."
    systemctl start postgresql
    systemctl enable postgresql
    
    # Verify PostgreSQL is running
    if systemctl is-active --quiet postgresql; then
        log_success "PostgreSQL installed and running successfully"
    else
        log_error "PostgreSQL installation completed but service is not running"
        exit 1
    fi
    
    # Get PostgreSQL version
    local pg_version=$(sudo -u postgres psql -t -c "SELECT version();" | head -n 1)
    log_info "PostgreSQL version: ${pg_version}"
}

# ====================
# PostgreSQL Configuration
# ====================

configure_postgresql() {
    log_info "Starting PostgreSQL configuration..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Find PostgreSQL configuration directory
    local pg_config_dir=$(sudo -u postgres psql -t -c "SHOW config_file;" | xargs dirname)
    log_info "PostgreSQL config directory: ${pg_config_dir}"
    
    # Backup configuration files
    log_info "Backing up configuration files..."
    cp "${pg_config_dir}/pg_hba.conf" "${BACKUP_DIR}/pg_hba.conf"
    cp "${pg_config_dir}/postgresql.conf" "${BACKUP_DIR}/postgresql.conf"
    
    # Set postgres user password
    log_info "Setting postgres user password..."
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '${POSTGRES_PASSWORD}';"
    log_success "Postgres user password set"
    
    # Create custom user if requested
    if [ "${CREATE_CUSTOM_USER:-no}" = "yes" ]; then
        log_info "Creating custom database user: ${CUSTOM_USERNAME}"
        sudo -u postgres psql -c "CREATE USER ${CUSTOM_USERNAME} WITH PASSWORD '${CUSTOM_USER_PASSWORD}';" 2>/dev/null || \
        sudo -u postgres psql -c "ALTER USER ${CUSTOM_USERNAME} WITH PASSWORD '${CUSTOM_USER_PASSWORD}';"
        
        # Grant privileges
        sudo -u postgres psql -c "ALTER USER ${CUSTOM_USERNAME} WITH CREATEDB;"
        log_success "Custom user created: ${CUSTOM_USERNAME}"
    fi
    
    # Create custom database if requested
    if [ "${CREATE_CUSTOM_DATABASE:-no}" = "yes" ]; then
        log_info "Creating custom database: ${CUSTOM_DATABASE_NAME}"
        sudo -u postgres psql -c "CREATE DATABASE ${CUSTOM_DATABASE_NAME};" 2>/dev/null || log_warning "Database ${CUSTOM_DATABASE_NAME} may already exist"
        
        if [ "${CREATE_CUSTOM_USER:-no}" = "yes" ]; then
            log_info "Granting privileges to ${CUSTOM_USERNAME} on ${CUSTOM_DATABASE_NAME}"
            sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${CUSTOM_DATABASE_NAME} TO ${CUSTOM_USERNAME};"
            sudo -u postgres psql -d "${CUSTOM_DATABASE_NAME}" -c "GRANT ALL ON SCHEMA public TO ${CUSTOM_USERNAME};"
        fi
        
        log_success "Custom database created: ${CUSTOM_DATABASE_NAME}"
    fi
    
    # Apply performance tuning if requested
    if [ "${APPLY_PERFORMANCE_TUNING:-no}" = "yes" ]; then
        apply_performance_tuning "${pg_config_dir}/postgresql.conf"
    else
        log_info "Performance tuning skipped (APPLY_PERFORMANCE_TUNING not enabled)"
    fi
    
    # Configure remote access if requested
    if [ "${ENABLE_REMOTE_ACCESS:-no}" = "yes" ]; then
        log_warning "Configuring remote access to PostgreSQL..."
        
        # Modify postgresql.conf to listen on all interfaces
        log_info "Configuring postgresql.conf to listen on all addresses..."
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "${pg_config_dir}/postgresql.conf"
        sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/" "${pg_config_dir}/postgresql.conf"
        
        # Modify pg_hba.conf to allow remote connections
        log_info "Configuring pg_hba.conf to allow remote connections..."
        echo "" >> "${pg_config_dir}/pg_hba.conf"
        echo "# Allow remote connections (added by install script)" >> "${pg_config_dir}/pg_hba.conf"
        echo "host    all             all             ${ALLOWED_IP_RANGE}         md5" >> "${pg_config_dir}/pg_hba.conf"
        
        log_warning "Remote access enabled for IP range: ${ALLOWED_IP_RANGE}"
        log_warning "SECURITY: Make sure your firewall is properly configured!"
    fi
    
    # Restart PostgreSQL to apply changes
    log_info "Restarting PostgreSQL to apply configuration changes..."
    systemctl restart postgresql
    
    if systemctl is-active --quiet postgresql; then
        log_success "PostgreSQL configuration completed successfully"
    else
        log_error "PostgreSQL failed to restart after configuration"
        exit 1
    fi
}

# ====================
# pgAdmin4 Installation
# ====================

install_pgadmin() {
    log_info "Starting pgAdmin4 installation..."
    
    # Install prerequisites
    log_info "Installing prerequisites..."
    apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates
    
    # Add pgAdmin4 repository
    log_info "Adding pgAdmin4 repository..."
    
    # Import repository signing key
    curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | gpg --dearmor -o /usr/share/keyrings/pgadmin-archive-keyring.gpg
    
    # Add repository
    echo "deb [signed-by=/usr/share/keyrings/pgadmin-archive-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/noble pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list
    
    # Update package lists
    log_info "Updating package lists with pgAdmin4 repository..."
    apt-get update
    
    # Install pgAdmin4
    log_info "Installing pgAdmin4 Web..."
    apt-get install -y pgadmin4-web
    
    PGADMIN_INSTALLED=true
    
    log_success "pgAdmin4 package installed"
}

configure_pgadmin() {
    log_info "Configuring pgAdmin4..."
    
    # Setup pgAdmin in non-interactive mode
    log_info "Running pgAdmin4 setup script..."
    
    # Create setup script responses
    cat > /tmp/pgadmin_setup_input.txt <<EOF
${PGADMIN_EMAIL}
${PGADMIN_PASSWORD}
${PGADMIN_PASSWORD}
y
EOF
    
    # Run pgAdmin4 setup script
    /usr/pgadmin4/bin/setup-web.sh < /tmp/pgadmin_setup_input.txt
    
    # Remove temporary file
    rm -f /tmp/pgadmin_setup_input.txt
    
    # Restart Apache to ensure pgAdmin is accessible
    log_info "Restarting Apache2 service..."
    systemctl restart apache2
    systemctl enable apache2
    
    if systemctl is-active --quiet apache2; then
        log_success "pgAdmin4 configured successfully"
    else
        log_error "Apache2 service failed to start"
        exit 1
    fi
}

# ====================
# Verification
# ====================

verify_installation() {
    log_info "Verifying installation..."
    
    # Check PostgreSQL
    if systemctl is-active --quiet postgresql; then
        log_success "✓ PostgreSQL service is running"
    else
        log_error "✗ PostgreSQL service is not running"
        return 1
    fi
    
    # Test PostgreSQL connection
    log_info "Testing PostgreSQL connection..."
    if sudo -u postgres psql -c "\l" > /dev/null 2>&1; then
        log_success "✓ PostgreSQL connection successful"
    else
        log_error "✗ Failed to connect to PostgreSQL"
        return 1
    fi
    
    # Check custom database if created
    if [ "${CREATE_CUSTOM_DATABASE:-no}" = "yes" ]; then
        if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "${CUSTOM_DATABASE_NAME}"; then
            log_success "✓ Custom database '${CUSTOM_DATABASE_NAME}' exists"
        else
            log_warning "✗ Custom database '${CUSTOM_DATABASE_NAME}' not found"
        fi
    fi
    
    # Verify performance settings if applied
    if [ "${APPLY_PERFORMANCE_TUNING:-no}" = "yes" ]; then
        log_info "Verifying performance settings..."
        local shared_buffers=$(sudo -u postgres psql -t -c "SHOW shared_buffers;" | xargs)
        local effective_cache=$(sudo -u postgres psql -t -c "SHOW effective_cache_size;" | xargs)
        log_success "✓ Performance tuning applied (shared_buffers: ${shared_buffers}, effective_cache_size: ${effective_cache})"
    fi
    
    # Check pgAdmin
    if systemctl is-active --quiet apache2; then
        log_success "✓ Apache2 (pgAdmin4) service is running"
    else
        log_error "✗ Apache2 service is not running"
        return 1
    fi
    
    # Check if pgAdmin is accessible
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/pgadmin4 | grep -q "200\|302"; then
        log_success "✓ pgAdmin4 web interface is accessible"
    else
        log_warning "✗ pgAdmin4 web interface may not be accessible (this can be normal)"
    fi
    
    log_success "Installation verification completed"
}

# ====================
# Display Information
# ====================

display_connection_info() {
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=========================================="
    echo "  Installation Completed Successfully!"
    echo "=========================================="
    echo ""
    echo -e "${GREEN}PostgreSQL Information:${NC}"
    echo "  - Service Status: Running"
    echo "  - Port: 5432"
    echo "  - Superuser: postgres"
    echo "  - Superuser Password: ${POSTGRES_PASSWORD}"
    
    if [ "${APPLY_PERFORMANCE_TUNING:-no}" = "yes" ]; then
        echo ""
        echo -e "${GREEN}Performance Tuning:${NC}"
        echo "  - Profile: ${PERFORMANCE_PROFILE}"
        echo "  - Shared Buffers: ${PERF_SHARED_BUFFERS}"
        echo "  - Effective Cache Size: ${PERF_EFFECTIVE_CACHE_SIZE}"
        echo "  - Max Connections: ${PERF_MAX_CONNECTIONS}"
        echo "  - Disk Type Optimized: ${DETECTED_DISK_TYPE}"
    fi
    
    if [ "${CREATE_CUSTOM_USER:-no}" = "yes" ]; then
        echo ""
        echo -e "${GREEN}Custom Database User:${NC}"
        echo "  - Username: ${CUSTOM_USERNAME}"
        echo "  - Password: ${CUSTOM_USER_PASSWORD}"
    fi
    
    if [ "${CREATE_CUSTOM_DATABASE:-no}" = "yes" ]; then
        echo ""
        echo -e "${GREEN}Custom Database:${NC}"
        echo "  - Database Name: ${CUSTOM_DATABASE_NAME}"
        echo "  - Owner: ${CUSTOM_DATABASE_OWNER}"
    fi
    
    echo ""
    echo -e "${GREEN}pgAdmin4 Web Interface:${NC}"
    echo "  - Local URL: http://localhost/pgadmin4"
    echo "  - Remote URL: http://${server_ip}/pgadmin4"
    echo "  - Email: ${PGADMIN_EMAIL}"
    echo "  - Password: ${PGADMIN_PASSWORD}"
    
    if [ "${ENABLE_REMOTE_ACCESS:-no}" = "yes" ]; then
        echo ""
        echo -e "${YELLOW}Remote Access Configuration:${NC}"
        echo "  - Remote connections: ENABLED"
        echo "  - Allowed IP Range: ${ALLOWED_IP_RANGE}"
        echo "  - Connection string: psql -h ${server_ip} -U ${CUSTOM_USERNAME:-postgres} -d ${CUSTOM_DATABASE_NAME:-postgres}"
        echo ""
        echo -e "${RED}SECURITY WARNING:${NC} Remote access is enabled!"
        echo "  Make sure your firewall is properly configured."
        echo "  To allow PostgreSQL through UFW firewall:"
        echo "    sudo ufw allow 5432/tcp"
    fi
    
    echo ""
    echo -e "${GREEN}Useful Commands:${NC}"
    echo "  - Check PostgreSQL status: sudo systemctl status postgresql"
    echo "  - Connect to PostgreSQL: sudo -u postgres psql"
    if [ "${CREATE_CUSTOM_DATABASE:-no}" = "yes" ]; then
        echo "  - Connect to custom DB: psql -U ${CUSTOM_USERNAME} -d ${CUSTOM_DATABASE_NAME} -h localhost"
    fi
    echo "  - Check pgAdmin status: sudo systemctl status apache2"
    if [ "${APPLY_PERFORMANCE_TUNING:-no}" = "yes" ]; then
        echo "  - View PostgreSQL config: sudo -u postgres psql -c 'SHOW ALL;'"
    fi
    echo "  - View installation log: cat ${LOG_FILE}"
    echo ""
    echo "=========================================="
    echo ""
}

# ====================
# Main Execution
# ====================

main() {
    echo ""
    echo "=========================================="
    echo " PostgreSQL & pgAdmin4 Installation"
    echo " Ubuntu 24.04 LTS"
    echo "=========================================="
    echo ""
    
    # Initialize logging (before config is loaded)
    LOG_FILE="$(mktemp -t postgresql_pgadmin_install_XXXXXX.log)"
    log_info "Starting installation script..."
    log_info "Temporary log file: ${LOG_FILE}"
    
    # Pre-flight checks
    check_root
    check_ubuntu_version
    load_config
    
    # Update LOG_FILE from config
    if [ -n "${LOG_FILE:-}" ]; then
        local new_log="${LOG_FILE}"
        # Copy temp log to configured location
        cat "$(ls -t /tmp/postgresql_pgadmin_install_*.log 2>/dev/null | head -1)" > "${new_log}" 2>/dev/null || true
        LOG_FILE="${new_log}"
        log_info "Log file set to: ${LOG_FILE}"
    fi
    
    check_existing_installations
    
    # Mark installation as started (for rollback purposes)
    INSTALLATION_STARTED=true
    
    # Install and configure PostgreSQL
    install_postgresql
    configure_postgresql
    
    # Install and configure pgAdmin
    install_pgadmin
    configure_pgadmin
    
    # Verify everything is working
    verify_installation
    
    # Display connection information
    display_connection_info
    
    log_success "Installation completed successfully!"
    log_info "Full installation log saved to: ${LOG_FILE}"
}

# Run main function
main "$@"
