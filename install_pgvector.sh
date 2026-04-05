#!/bin/bash

###############################################################################
# pgVector Extension Installation Script for Ubuntu 24.04
# 
# This script automates the installation and configuration of:
#   - pgvector extension for PostgreSQL
#   - Extension enablement in specific databases
#   - Comprehensive verification with vector operations
#
# Usage: 
#   Install:   sudo ./install_pgvector.sh
#   Uninstall: sudo ./install_pgvector.sh --uninstall
#   Help:      sudo ./install_pgvector.sh --help
# 
# Requirements:
#   - Ubuntu 24.04 LTS (recommended)
#   - Root/sudo privileges
#   - PostgreSQL already installed and running
#   - Configured configs/install_pgvector_config.conf file
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# ====================
# Global Variables
# ====================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/configs/install_pgvector_config.conf"
INSTALLATION_STARTED=false
PGVECTOR_INSTALLED=false
DATABASES_WITH_EXTENSION=()  # Track databases where extension was enabled
DETECTED_PG_VERSION=""
MODE="install"  # install, uninstall, or help
FORCE_MODE=false

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
    echo -e "${timestamp} - ${message}" >> "${LOG_FILE:-/tmp/install_pgvector.log}"
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
    echo "              pgVector Extension Installation Script"
    echo "============================================================================="
    echo -e "${NC}"
    log_info "Starting pgvector installation process..."
}

display_uninstall_banner() {
    echo -e "${YELLOW}"
    echo "============================================================================="
    echo "              pgVector Extension Uninstall Script"
    echo "============================================================================="
    echo -e "${NC}"
    log_info "Starting pgvector uninstall process..."
}

display_help() {
    cat << EOF
pgVector Extension Installation Script

USAGE:
    sudo ./install_pgvector.sh [OPTIONS]

OPTIONS:
    (none)          Install pgvector extension (default mode)
    --uninstall     Remove pgvector extension from all databases
    --force         Skip confirmation prompts (uninstall only)
    --help          Display this help message

EXAMPLES:
    # Install pgvector
    sudo ./install_pgvector.sh

    # Uninstall with confirmation
    sudo ./install_pgvector.sh --uninstall

    # Uninstall without confirmation
    sudo ./install_pgvector.sh --uninstall --force

REQUIREMENTS:
    - Ubuntu 24.04 LTS (recommended)
    - Root/sudo privileges
    - PostgreSQL already installed and running
    - Configured configs/install_pgvector_config.conf file

CONFIGURATION:
    Edit configs/install_pgvector_config.conf before installation
    Secure the file: chmod 600 configs/install_pgvector_config.conf

For more information, see README.md
EOF
}

# ====================
# Error Handler and Cleanup
# ====================

cleanup_on_error() {
    local exit_code=$?
    
    # Disable ERR trap and 'set -e' to avoid recursive error handling
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
    
    # Drop extension from databases where it was installed
    if [ ${#DATABASES_WITH_EXTENSION[@]} -gt 0 ]; then
        log_info "Removing pgvector extension from databases..."
        for db in "${DATABASES_WITH_EXTENSION[@]}"; do
            log_info "Dropping extension from database: ${db}"
            sudo -u postgres psql -d "${db}" -c "DROP EXTENSION IF EXISTS vector CASCADE;" 2>/dev/null || true
        done
    fi
    
    # Remove package if it was installed
    if [ "$PGVECTOR_INSTALLED" = true ]; then
        log_info "Removing pgvector package..."
        apt-get remove -y postgresql-*-pgvector 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
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
        log_warning "This script is designed for Ubuntu. Detected: $ID"
        log_warning "Proceeding anyway, but compatibility may vary..."
    elif [ "$VERSION_ID" != "24.04" ]; then
        log_warning "This script is optimized for Ubuntu 24.04. Detected: $VERSION_ID"
        log_warning "Proceeding anyway, but some features may not work as expected..."
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
    
    # Validate required variables (only for install mode)
    if [ "$MODE" = "install" ]; then
        if [ -z "${TARGET_DATABASES:-}" ]; then
            log_error "TARGET_DATABASES not set in config file"
            exit 1
        fi
        
        if [ "${TARGET_DATABASES}" = "" ]; then
            log_error "TARGET_DATABASES cannot be empty. Specify at least one database."
            exit 1
        fi
        
        log_success "Configuration loaded and validated"
    else
        log_success "Configuration loaded"
    fi
}

check_postgresql_installed() {
    log_info "Checking for PostgreSQL installation..."
    
    # Check if PostgreSQL is installed
    if ! command -v psql &> /dev/null; then
        log_error "PostgreSQL client (psql) not found"
        log_error "Please install PostgreSQL first using install_postgresql_pgadmin.sh"
        exit 1
    fi
    
    # Check if PostgreSQL service is running
    if ! systemctl is-active --quiet postgresql 2>/dev/null; then
        log_error "PostgreSQL service is not running"
        log_error "Please start PostgreSQL: sudo systemctl start postgresql"
        exit 1
    fi
    
    log_success "PostgreSQL is installed and running"
}

detect_postgresql_version() {
    log_info "Detecting PostgreSQL version..."
    
    # Get the installed PostgreSQL version
    local pg_version=$(sudo -u postgres psql -t -c "SHOW server_version;" 2>/dev/null | awk '{print $1}' | cut -d. -f1)
    
    if [ -z "$pg_version" ]; then
        log_error "Failed to detect PostgreSQL version"
        exit 1
    fi
    
    DETECTED_PG_VERSION="$pg_version"
    log_success "Detected PostgreSQL version: ${DETECTED_PG_VERSION}"
}

check_existing_pgvector() {
    log_info "Checking for existing pgvector installation..."
    
    # Check if package is installed
    # Temporarily disable pipefail to avoid SIGPIPE from dpkg when grep exits early
    set +o pipefail
    if dpkg -l | grep -q "postgresql-.*-pgvector"; then
        local installed_version=$(dpkg -l | grep "postgresql-.*-pgvector" | awk '{print $3}')
        set -o pipefail
        log_warning "pgvector package is already installed (version: ${installed_version})"
        log_warning "Installation will proceed and may upgrade the package"
        return 0
    fi
    set -o pipefail
    
    # Check if extension exists in any database
    local existing_dbs=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0') AND oid IN (SELECT extnamespace FROM pg_extension WHERE extname='vector');" 2>/dev/null | xargs)
    
    if [ -n "$existing_dbs" ]; then
        log_warning "pgvector extension found in databases: ${existing_dbs}"
        log_warning "These databases will be skipped during installation"
    else
        log_success "No existing pgvector installation detected"
    fi
}

# ====================
# Installation Functions
# ====================

install_pgvector_package() {
    log_info "Installing pgvector package..."
    
    # Determine which version to install
    local target_version="${POSTGRES_VERSION:-$DETECTED_PG_VERSION}"
    
    if [ -z "$target_version" ]; then
        log_error "Cannot determine PostgreSQL version"
        exit 1
    fi
    
    local package_name="postgresql-${target_version}-pgvector"
    
    log_info "Target package: ${package_name}"
    
    # Update package lists
    log_info "Updating package lists..."
    apt-get update -qq
    
    # Install pgvector
    log_info "Installing ${package_name}..."
    if apt-get install -y "${package_name}"; then
        PGVECTOR_INSTALLED=true
        log_success "pgvector package installed successfully"
    else
        log_error "Failed to install ${package_name}"
        log_error "The package may not be available for PostgreSQL ${target_version}"
        log_info "Try installing build-essential and postgresql-server-dev-${target_version} to build from source"
        exit 1
    fi
}

enable_pgvector_in_databases() {
    log_info "Enabling pgvector extension in databases..."
    
    # Convert comma-separated list to array
    IFS=',' read -ra DB_ARRAY <<< "$TARGET_DATABASES"
    
    for db in "${DB_ARRAY[@]}"; do
        # Trim whitespace
        db=$(echo "$db" | xargs)
        
        log_info "Enabling pgvector in database: ${db}"
        
        # Check if database exists
        if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$db"; then
            log_warning "Database '${db}' does not exist. Skipping..."
            continue
        fi
        
        # Check if extension already exists
        local ext_exists=$(sudo -u postgres psql -d "$db" -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null | xargs)
        
        if [ "$ext_exists" = "1" ]; then
            log_warning "pgvector extension already enabled in database: ${db}"
            continue
        fi
        
        # Create extension
        if sudo -u postgres psql -d "$db" -c "CREATE EXTENSION IF NOT EXISTS vector;" > /dev/null 2>&1; then
            DATABASES_WITH_EXTENSION+=("$db")
            log_success "pgvector enabled in database: ${db}"
        else
            log_error "Failed to enable pgvector in database: ${db}"
            exit 1
        fi
    done
    
    # Enable in template1 if requested
    if [ "${ENABLE_IN_TEMPLATE1:-no}" = "yes" ]; then
        log_info "Enabling pgvector in template1 for future databases..."
        
        local ext_exists=$(sudo -u postgres psql -d template1 -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null | xargs)
        
        if [ "$ext_exists" = "1" ]; then
            log_warning "pgvector extension already enabled in template1"
        else
            if sudo -u postgres psql -d template1 -c "CREATE EXTENSION IF NOT EXISTS vector;" > /dev/null 2>&1; then
                log_success "pgvector enabled in template1"
            else
                log_error "Failed to enable pgvector in template1"
                exit 1
            fi
        fi
    fi
    
    if [ ${#DATABASES_WITH_EXTENSION[@]} -eq 0 ]; then
        log_warning "No new databases were configured with pgvector"
    else
        log_success "pgvector enabled in ${#DATABASES_WITH_EXTENSION[@]} database(s)"
    fi
}

# ====================
# Verification Functions
# ====================

verify_pgvector_installation() {
    log_info "Verifying pgvector installation..."
    
    # Check package installation
    # Temporarily disable pipefail to avoid SIGPIPE from dpkg when grep exits early
    set +o pipefail
    if ! dpkg -l | grep -q "postgresql-.*-pgvector"; then
        set -o pipefail
        log_error "pgvector package not found in system packages"
        return 1
    fi
    
    local installed_version=$(dpkg -l | grep "postgresql-.*-pgvector" | awk '{print $3}')
    set -o pipefail
    log_success "Package verification: postgresql-pgvector ${installed_version} is installed"
    
    # Skip tests if not requested
    if [ "${RUN_VERIFICATION_TESTS:-yes}" != "yes" ]; then
        log_info "Verification tests skipped (RUN_VERIFICATION_TESTS=no)"
        return 0
    fi
    
    # Run comprehensive tests on databases with extension
    local test_passed=true
    
    if [ ${#DATABASES_WITH_EXTENSION[@]} -gt 0 ]; then
        for db in "${DATABASES_WITH_EXTENSION[@]}"; do
            log_info "Running verification tests on database: ${db}"
            
            if run_vector_tests "$db"; then
                log_success "Verification tests passed for database: ${db}"
            else
                log_error "Verification tests failed for database: ${db}"
                test_passed=false
            fi
        done
    else
        # Test on first configured database
        IFS=',' read -ra DB_ARRAY <<< "$TARGET_DATABASES"
        local test_db=$(echo "${DB_ARRAY[0]}" | xargs)
        
        if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$test_db"; then
            log_info "Running verification tests on database: ${test_db}"
            
            if run_vector_tests "$test_db"; then
                log_success "Verification tests passed for database: ${test_db}"
            else
                log_error "Verification tests failed for database: ${test_db}"
                test_passed=false
            fi
        fi
    fi
    
    if [ "$test_passed" = true ]; then
        log_success "All verification tests passed"
        return 0
    else
        return 1
    fi
}

run_vector_tests() {
    local db="$1"
    local test_dim="${TEST_VECTOR_DIMENSION:-3}"
    local test_table="pgvector_test_$$"  # Use PID for unique table name
    
    # Check if extension exists
    local ext_version=$(sudo -u postgres psql -d "$db" -t -c "SELECT extversion FROM pg_extension WHERE extname='vector';" 2>/dev/null | xargs)
    
    if [ -z "$ext_version" ]; then
        log_error "pgvector extension not found in database: ${db}"
        return 1
    fi
    
    log_info "  Extension version: ${ext_version}"
    
    # Test 1: Create table with vector column
    log_info "  Test 1: Creating test table with vector(${test_dim}) column..."
    if ! sudo -u postgres psql -d "$db" -c "CREATE TABLE ${test_table} (id serial PRIMARY KEY, embedding vector(${test_dim}));" > /dev/null 2>&1; then
        log_error "  Failed to create test table"
        return 1
    fi
    
    # Test 2: Insert test vectors
    log_info "  Test 2: Inserting test vectors..."
    if ! sudo -u postgres psql -d "$db" -c "INSERT INTO ${test_table} (embedding) VALUES ('[1,2,3]'), ('[4,5,6]'), ('[7,8,9]');" > /dev/null 2>&1; then
        log_error "  Failed to insert test vectors"
        sudo -u postgres psql -d "$db" -c "DROP TABLE IF EXISTS ${test_table};" > /dev/null 2>&1
        return 1
    fi
    
    # Test 3: L2 distance calculation
    log_info "  Test 3: Testing L2 distance calculation..."
    local l2_result=$(sudo -u postgres psql -d "$db" -t -c "SELECT embedding <-> '[1,2,3]' as distance FROM ${test_table} ORDER BY distance LIMIT 1;" 2>/dev/null | xargs)
    
    if [ -z "$l2_result" ]; then
        log_error "  Failed to calculate L2 distance"
        sudo -u postgres psql -d "$db" -c "DROP TABLE IF EXISTS ${test_table};" > /dev/null 2>&1
        return 1
    fi
    
    log_info "  L2 distance test result: ${l2_result}"
    
    # Test 4: Inner product (cosine similarity)
    log_info "  Test 4: Testing inner product (cosine similarity)..."
    local ip_result=$(sudo -u postgres psql -d "$db" -t -c "SELECT embedding <#> '[1,2,3]' as neg_inner_product FROM ${test_table} ORDER BY neg_inner_product LIMIT 1;" 2>/dev/null | xargs)
    
    if [ -z "$ip_result" ]; then
        log_error "  Failed to calculate inner product"
        sudo -u postgres psql -d "$db" -c "DROP TABLE IF EXISTS ${test_table};" > /dev/null 2>&1
        return 1
    fi
    
    log_info "  Inner product test result: ${ip_result}"
    
    # Test 5: Create index (IVFFlat)
    log_info "  Test 5: Testing IVFFlat index creation..."
    if ! sudo -u postgres psql -d "$db" -c "CREATE INDEX ON ${test_table} USING ivfflat (embedding vector_l2_ops) WITH (lists = 1);" > /dev/null 2>&1; then
        log_warning "  IVFFlat index creation failed (may need more data or pgvector >= 0.5.0)"
    else
        log_info "  IVFFlat index created successfully"
    fi
    
    # Test 6: Test HNSW index (if available)
    log_info "  Test 6: Testing HNSW index creation..."
    if ! sudo -u postgres psql -d "$db" -c "DROP INDEX IF EXISTS ${test_table}_embedding_idx; CREATE INDEX ${test_table}_embedding_idx ON ${test_table} USING hnsw (embedding vector_l2_ops);" > /dev/null 2>&1; then
        log_warning "  HNSW index creation failed (may require pgvector >= 0.5.0)"
    else
        log_info "  HNSW index created successfully"
    fi
    
    # Cleanup
    log_info "  Cleaning up test table..."
    sudo -u postgres psql -d "$db" -c "DROP TABLE IF EXISTS ${test_table};" > /dev/null 2>&1
    
    log_success "  All vector operation tests completed successfully"
    return 0
}

# ====================
# Uninstall Functions
# ====================

uninstall_pgvector() {
    log_info "Starting pgvector uninstall process..."
    
    # Confirm uninstall unless force mode
    if [ "$FORCE_MODE" != true ]; then
        echo -e "${YELLOW}WARNING: This will remove pgvector extension from all databases and uninstall the package.${NC}"
        read -p "Are you sure you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Uninstall cancelled by user"
            exit 0
        fi
    fi
    
    # Find all databases with vector extension
    log_info "Detecting databases with pgvector extension..."
    set +o pipefail
    local dbs_with_vector=$(sudo -u postgres psql -t -c "SELECT d.datname FROM pg_database d JOIN pg_extension e ON d.oid = e.extnamespace WHERE e.extname='vector' AND d.datname NOT IN ('template0');" 2>/dev/null | xargs)
    set -o pipefail
    
    if [ -n "$dbs_with_vector" ]; then
        log_info "Found pgvector in databases: ${dbs_with_vector}"
        
        # Drop extension from each database
        for db in $dbs_with_vector; do
            log_info "Dropping pgvector extension from database: ${db}"
            if sudo -u postgres psql -d "$db" -c "DROP EXTENSION IF EXISTS vector CASCADE;" > /dev/null 2>&1; then
                log_success "Extension dropped from database: ${db}"
            else
                log_error "Failed to drop extension from database: ${db}"
            fi
        done
    else
        log_info "No databases found with pgvector extension"
    fi
    
    # Remove package
    set +o pipefail
    if dpkg -l | grep -q "postgresql-.*-pgvector"; then
        set -o pipefail
        log_info "Removing pgvector package..."
        if apt-get remove -y postgresql-*-pgvector; then
            log_success "pgvector package removed"
            
            log_info "Running autoremove to clean up dependencies..."
            apt-get autoremove -y > /dev/null 2>&1
        else
            log_error "Failed to remove pgvector package"
            exit 1
        fi
    else
        log_info "pgvector package not found in system"
    fi
    
    log_success "pgvector uninstall completed successfully"
}

# ====================
# Display Functions
# ====================

display_installation_info() {
    local target_version="${POSTGRES_VERSION:-$DETECTED_PG_VERSION}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Installation Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "PostgreSQL Version: ${target_version}"
    echo -e "Target Databases:   ${TARGET_DATABASES}"
    echo -e "Enable in template1: ${ENABLE_IN_TEMPLATE1:-no}"
    echo -e "Run Tests:          ${RUN_VERIFICATION_TESTS:-yes}"
    echo -e "Log File:           ${LOG_FILE}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

display_success_info() {
    local installed_version=$(dpkg -l | grep "postgresql-.*-pgvector" | awk '{print $3}')
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Installation Completed Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "pgvector Version: ${installed_version}"
    echo -e "Databases Configured: ${#DATABASES_WITH_EXTENSION[@]}"
    
    if [ ${#DATABASES_WITH_EXTENSION[@]} -gt 0 ]; then
        echo -e "Database List:"
        for db in "${DATABASES_WITH_EXTENSION[@]}"; do
            echo -e "  - ${db}"
        done
    fi
    
    echo -e ""
    echo -e "You can now use vector operations in PostgreSQL:"
    echo -e "  CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));"
    echo -e "  INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');"
    echo -e "  SELECT * FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 5;"
    echo -e ""
    echo -e "For more information: https://github.com/pgvector/pgvector"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    log_success "Installation completed successfully"
}

# ====================
# Main Function
# ====================

main() {
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --uninstall)
                MODE="uninstall"
                shift
                ;;
            --force)
                FORCE_MODE=true
                shift
                ;;
            --help|-h)
                display_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Execute based on mode
    if [ "$MODE" = "uninstall" ]; then
        display_uninstall_banner
        check_root
        check_postgresql_installed
        uninstall_pgvector
        exit 0
    fi
    
    # Install mode
    display_banner
    check_root
    check_ubuntu_version
    load_config
    check_postgresql_installed
    detect_postgresql_version
    check_existing_pgvector
    
    display_installation_info
    
    # Confirm installation
    read -p "Proceed with installation? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Installation cancelled by user"
        exit 0
    fi
    
    INSTALLATION_STARTED=true
    
    install_pgvector_package
    enable_pgvector_in_databases
    verify_pgvector_installation
    
    display_success_info
}

# Run main function
main "$@"
