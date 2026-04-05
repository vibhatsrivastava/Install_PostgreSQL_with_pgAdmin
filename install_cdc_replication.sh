#!/bin/bash

###############################################################################
# PostgreSQL CDC & Vector Embedding Installation Script
# 
# This script automates the setup of:
#   - PostgreSQL logical replication (CDC) between databases
#   - Automated DDL propagation via event triggers
#   - Automatic vector embedding generation via Ollama
#   - Prometheus monitoring integration
#
# Usage: sudo ./install_cdc_replication.sh
# 
# Requirements:
#   - Ubuntu 24.04 LTS (recommended)
#   - Root/sudo privileges
#   - PostgreSQL already installed and running
#   - Ollama installed with nomic-embed-text model
#   - Configured configs/install_cdc_config.conf file
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# ====================
# Global Variables
# ====================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/configs/install_cdc_config.conf"
BACKUP_DIR="/tmp/postgresql_cdc_backup_$(date +%Y%m%d_%H%M%S)"
INSTALLATION_STARTED=false
CONFIG_MODIFIED=false
TARGET_DB_CREATED=false
REPLICATION_CONFIGURED=false
DDL_WORKER_INSTALLED=false
EMBEDDINGS_CONFIGURED=false
MONITORING_INSTALLED=false
DETECTED_PG_VERSION=""

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
    echo -e "${timestamp} - ${message}" >> "${LOG_FILE:-/tmp/cdc_install.log}"
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
    echo "    PostgreSQL CDC & Vector Embedding Installation Script"
    echo "============================================================================="
    echo -e "${NC}"
    log_info "Starting CDC replication setup process..."
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
    
    # Stop DDL worker service
    if [ "$DDL_WORKER_INSTALLED" = true ]; then
        log_info "Stopping DDL replication worker..."
        systemctl stop ddl-replication-worker 2>/dev/null || true
        systemctl disable ddl-replication-worker 2>/dev/null || true
        rm -f /etc/systemd/system/ddl-replication-worker.service
        rm -f /usr/local/bin/replicate_ddl_changes.py
        systemctl daemon-reload
    fi
    
    # Stop postgres_exporter
    if [ "$MONITORING_INSTALLED" = true ]; then
        log_info "Stopping postgres_exporter..."
        systemctl stop postgres_exporter 2>/dev/null || true
        systemctl disable postgres_exporter 2>/dev/null || true
        rm -f /etc/systemd/system/postgres_exporter.service
        systemctl daemon-reload
    fi
    
    # Remove replication setup
    if [ "$REPLICATION_CONFIGURED" = true ]; then
        log_info "Removing replication configuration..."
        sudo -u postgres psql -d "${TARGET_DATABASE}" -c "DROP SUBSCRIPTION IF EXISTS ${SUBSCRIPTION_NAME};" 2>/dev/null || true
        sudo -u postgres psql -d "${SOURCE_DATABASE}" -c "DROP PUBLICATION IF EXISTS ${PUBLICATION_NAME};" 2>/dev/null || true
        sudo -u postgres psql -d "${SOURCE_DATABASE}" -c "DROP EVENT TRIGGER IF EXISTS capture_ddl_changes CASCADE;" 2>/dev/null || true
    fi
    
    # Drop target database
    if [ "$TARGET_DB_CREATED" = true ]; then
        log_info "Dropping target database..."
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${TARGET_DATABASE};" 2>/dev/null || true
    fi
    
    # Restore backed up configuration files
    if [ "$CONFIG_MODIFIED" = true ] && [ -d "$BACKUP_DIR" ]; then
        log_info "Restoring backed up configuration files..."
        if [ -f "${BACKUP_DIR}/postgresql.conf" ]; then
            local pg_config_dir=$(get_pg_config_dir)
            cp "${BACKUP_DIR}/postgresql.conf" "${pg_config_dir}/postgresql.conf" 2>/dev/null || true
        fi
        
        log_info "Restarting PostgreSQL to apply original configuration..."
        systemctl restart postgresql 2>/dev/null || true
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
    
    if [ -z "${SOURCE_DATABASE:-}" ]; then
        log_error "SOURCE_DATABASE not set in config file"
        exit 1
    fi
    
    if [ -z "${TARGET_DATABASE:-}" ]; then
        log_error "TARGET_DATABASE not set in config file"
        exit 1
    fi
    
    if [ -z "${SOURCE_TABLE:-}" ]; then
        log_error "SOURCE_TABLE not set in config file"
        exit 1
    fi
    
    if [ -z "${TEXT_COLUMN_TO_VECTORIZE:-}" ]; then
        log_error "TEXT_COLUMN_TO_VECTORIZE not set in config file"
        exit 1
    fi
    
    if [ -z "${OLLAMA_API_URL:-}" ]; then
        log_error "OLLAMA_API_URL not set in config file"
        exit 1
    fi
    
    if [ -z "${OLLAMA_MODEL:-}" ]; then
        log_error "OLLAMA_MODEL not set in config file"
        exit 1
    fi
    
    if [ -z "${EMBEDDING_DIMENSION:-}" ]; then
        log_error "EMBEDDING_DIMENSION not set in config file"
        exit 1
    fi
    
    log_success "Configuration loaded and validated"
}

check_postgresql() {
    if ! systemctl is-active --quiet postgresql; then
        log_error "PostgreSQL service is not running"
        log_info "Please install and start PostgreSQL first: sudo ./install_postgresql_pgadmin.sh"
        exit 1
    fi
    
    if ! sudo -u postgres psql -c '\q' 2>/dev/null; then
        log_error "Cannot connect to PostgreSQL"
        exit 1
    fi
    
    log_success "PostgreSQL is running and accessible"
}

check_source_database() {
    log_info "Checking source database: ${SOURCE_DATABASE}"
    
    if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "${SOURCE_DATABASE}"; then
        log_error "Source database '${SOURCE_DATABASE}' does not exist"
        log_info "Please create the source database first"
        exit 1
    fi
    
    log_success "Source database exists"
    
    # Check if source table exists
    log_info "Checking source table: ${SOURCE_TABLE}"
    local table_exists=$(sudo -u postgres psql -d "${SOURCE_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='${SOURCE_TABLE}' AND table_schema='public';")
    
    if [ "$table_exists" -eq 0 ]; then
        log_error "Source table '${SOURCE_TABLE}' does not exist in database '${SOURCE_DATABASE}'"
        exit 1
    fi
    
    log_success "Source table exists"
    
    # Check if table has primary key
    local has_pk=$(sudo -u postgres psql -d "${SOURCE_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM information_schema.table_constraints 
         WHERE table_name='${SOURCE_TABLE}' AND constraint_type='PRIMARY KEY';")
    
    if [ "$has_pk" -eq 0 ]; then
        log_error "Source table '${SOURCE_TABLE}' must have a PRIMARY KEY for replication"
        log_info "Add a primary key: ALTER TABLE ${SOURCE_TABLE} ADD PRIMARY KEY (id);"
        exit 1
    fi
    
    log_success "Source table has primary key"
    
    # Check if text column exists
    local col_exists=$(sudo -u postgres psql -d "${SOURCE_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM information_schema.columns 
         WHERE table_name='${SOURCE_TABLE}' AND column_name='${TEXT_COLUMN_TO_VECTORIZE}';")
    
    if [ "$col_exists" -eq 0 ]; then
        log_error "Column '${TEXT_COLUMN_TO_VECTORIZE}' does not exist in table '${SOURCE_TABLE}'"
        exit 1
    fi
    
    log_success "Text column '${TEXT_COLUMN_TO_VECTORIZE}' exists"
}

check_ollama() {
    log_info "Checking Ollama service..."
    
    # Check if Ollama is accessible via API
    if ! curl -s "${OLLAMA_API_URL}/api/version" > /dev/null 2>&1; then
        log_error "Ollama is not accessible at ${OLLAMA_API_URL}"
        log_info "Please ensure Ollama is running: systemctl status ollama"
        log_info "Or start it manually: ollama serve"
        exit 1
    fi
    
    log_success "Ollama is running and accessible"
    
    # Check if model is available
    log_info "Checking if model '${OLLAMA_MODEL}' is available..."
    if ! curl -s "${OLLAMA_API_URL}/api/tags" | grep -q "\"${OLLAMA_MODEL}\""; then
        log_error "Model '${OLLAMA_MODEL}' is not available in Ollama"
        log_info "Please pull the model: ollama pull ${OLLAMA_MODEL}"
        exit 1
    fi
    
    log_success "Ollama model '${OLLAMA_MODEL}' is available"
}

detect_pg_version() {
    log_info "Detecting PostgreSQL version..."
    
    if [ -n "${POSTGRES_VERSION}" ]; then
        DETECTED_PG_VERSION="${POSTGRES_VERSION}"
        log_info "Using configured PostgreSQL version: ${DETECTED_PG_VERSION}"
    else
        DETECTED_PG_VERSION=$(sudo -u postgres psql -t -c "SHOW server_version;" | awk '{print $1}' | cut -d. -f1)
        log_info "Auto-detected PostgreSQL version: ${DETECTED_PG_VERSION}"
    fi
    
    if [ -z "$DETECTED_PG_VERSION" ]; then
        log_error "Failed to detect PostgreSQL version"
        exit 1
    fi
    
    log_success "PostgreSQL version: ${DETECTED_PG_VERSION}"
}

get_pg_config_dir() {
    local config_file=$(sudo -u postgres psql -t -c "SHOW config_file;" | xargs)
    dirname "$config_file"
}

# ====================
# Phase 1: PostgreSQL Configuration
# ====================

backup_postgresql_config() {
    log_info "Creating backup of PostgreSQL configuration..."
    
    mkdir -p "$BACKUP_DIR"
    local pg_config_dir=$(get_pg_config_dir)
    
    cp "${pg_config_dir}/postgresql.conf" "${BACKUP_DIR}/postgresql.conf"
    
    if [ -f "${pg_config_dir}/pg_hba.conf" ]; then
        cp "${pg_config_dir}/pg_hba.conf" "${BACKUP_DIR}/pg_hba.conf"
    fi
    
    log_success "Configuration backed up to: ${BACKUP_DIR}"
}

configure_logical_replication() {
    log_info "Configuring PostgreSQL for logical replication..."
    
    local pg_config_dir=$(get_pg_config_dir)
    local pg_config_file="${pg_config_dir}/postgresql.conf"
    
    # Check current wal_level
    local current_wal_level=$(sudo -u postgres psql -t -c "SHOW wal_level;" | xargs)
    
    if [ "$current_wal_level" = "logical" ]; then
        log_info "wal_level is already set to 'logical'"
    else
        log_info "Updating postgresql.conf for logical replication..."
        
        # Add or update replication settings
        cat >> "$pg_config_file" << EOF

# ====================
# Logical Replication Settings (Added by CDC installation script)
# ====================
wal_level = logical
max_replication_slots = ${MAX_REPLICATION_SLOTS}
max_wal_senders = ${MAX_WAL_SENDERS}
max_logical_replication_workers = ${MAX_LOGICAL_REPLICATION_WORKERS}
EOF
        
        CONFIG_MODIFIED=true
        log_success "PostgreSQL configuration updated"
        
        log_info "Restarting PostgreSQL to apply changes..."
        systemctl restart postgresql
        
        # Wait for PostgreSQL to be ready
        sleep 5
        
        # Verify new settings
        local new_wal_level=$(sudo -u postgres psql -t -c "SHOW wal_level;" | xargs)
        if [ "$new_wal_level" != "logical" ]; then
            log_error "Failed to enable logical replication. wal_level is: $new_wal_level"
            exit 1
        fi
        
        log_success "Logical replication enabled successfully"
    fi
}

# ====================
# Phase 2: Target Database Setup
# ====================

create_target_database() {
    log_info "Creating target database: ${TARGET_DATABASE}"
    
    # Check if database already exists
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "${TARGET_DATABASE}"; then
        log_warning "Database '${TARGET_DATABASE}' already exists"
        read -p "Do you want to drop and recreate it? (yes/no): " -r
        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            sudo -u postgres psql -c "DROP DATABASE ${TARGET_DATABASE};"
            log_info "Dropped existing database"
        else
            log_error "Cannot proceed with existing database"
            exit 1
        fi
    fi
    
    sudo -u postgres psql -c "CREATE DATABASE ${TARGET_DATABASE} OWNER postgres;"
    TARGET_DB_CREATED=true
    log_success "Target database created"
}

enable_pgvector_extension() {
    log_info "Enabling pgvector extension in target database..."
    
    sudo -u postgres psql -d "${TARGET_DATABASE}" -c "CREATE EXTENSION IF NOT EXISTS vector;"
    
    # Verify extension
    local ext_exists=$(sudo -u postgres psql -d "${TARGET_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM pg_extension WHERE extname='vector';")
    
    if [ "$ext_exists" -eq 0 ]; then
        log_error "Failed to enable pgvector extension"
        exit 1
    fi
    
    log_success "pgvector extension enabled"
}

replicate_table_schema() {
    log_info "Replicating table schema from source to target..."
    
    # Dump schema from source table
    local schema_file="/tmp/${SOURCE_TABLE}_schema.sql"
    sudo -u postgres pg_dump -s -t "${SOURCE_TABLE}" "${SOURCE_DATABASE}" > "$schema_file"
    
    # Apply schema to target database
    sudo -u postgres psql -d "${TARGET_DATABASE}" -f "$schema_file"
    
    # Clean up
    rm -f "$schema_file"
    
    log_success "Table schema replicated"
}

add_vector_column() {
    log_info "Adding vector column for embeddings..."
    
    local vector_col_name="${TEXT_COLUMN_TO_VECTORIZE}_embedding"
    
    # Check if column already exists
    local col_exists=$(sudo -u postgres psql -d "${TARGET_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM information_schema.columns 
         WHERE table_name='${SOURCE_TABLE}' AND column_name='${vector_col_name}';")
    
    if [ "$col_exists" -gt 0 ]; then
        log_info "Vector column already exists"
    else
        sudo -u postgres psql -d "${TARGET_DATABASE}" -c \
            "ALTER TABLE ${SOURCE_TABLE} ADD COLUMN ${vector_col_name} vector(${EMBEDDING_DIMENSION});"
        log_success "Vector column added: ${vector_col_name}"
    fi
    
    # Create IVFFlat index
    if [ "${ENABLE_EMBEDDING_GENERATION}" = "yes" ]; then
        log_info "Creating IVFFlat index for vector similarity search..."
        
        sudo -u postgres psql -d "${TARGET_DATABASE}" -c \
            "CREATE INDEX IF NOT EXISTS ${SOURCE_TABLE}_${vector_col_name}_idx 
             ON ${SOURCE_TABLE} USING ivfflat (${vector_col_name} vector_cosine_ops) 
             WITH (lists = ${IVFFLAT_LISTS});"
        
        log_success "IVFFlat index created"
    fi
}

# ====================
# Phase 3: Logical Replication Setup
# ====================

create_publication() {
    log_info "Creating publication in source database..."
    
    # Check if publication already exists
    local pub_exists=$(sudo -u postgres psql -d "${SOURCE_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM pg_publication WHERE pubname='${PUBLICATION_NAME}';")
    
    if [ "$pub_exists" -gt 0 ]; then
        log_warning "Publication '${PUBLICATION_NAME}' already exists, dropping..."
        sudo -u postgres psql -d "${SOURCE_DATABASE}" -c "DROP PUBLICATION ${PUBLICATION_NAME};"
    fi
    
    sudo -u postgres psql -d "${SOURCE_DATABASE}" -c \
        "CREATE PUBLICATION ${PUBLICATION_NAME} FOR TABLE ${SOURCE_TABLE};"
    
    log_success "Publication created: ${PUBLICATION_NAME}"
}

create_subscription() {
    log_info "Creating subscription in target database..."
    
    # Check if subscription already exists
    local sub_exists=$(sudo -u postgres psql -d "${TARGET_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM pg_subscription WHERE subname='${SUBSCRIPTION_NAME}';")
    
    if [ "$sub_exists" -gt 0 ]; then
        log_warning "Subscription '${SUBSCRIPTION_NAME}' already exists, dropping..."
        sudo -u postgres psql -d "${TARGET_DATABASE}" -c "DROP SUBSCRIPTION ${SUBSCRIPTION_NAME};"
    fi
    
    # Create connection string
    local conn_str="host=localhost port=5432 dbname=${SOURCE_DATABASE} user=postgres password=${POSTGRES_PASSWORD}"
    
    sudo -u postgres psql -d "${TARGET_DATABASE}" -c \
        "CREATE SUBSCRIPTION ${SUBSCRIPTION_NAME} 
         CONNECTION '${conn_str}' 
         PUBLICATION ${PUBLICATION_NAME} 
         WITH (copy_data = true, create_slot = true, enabled = true);"
    
    REPLICATION_CONFIGURED=true
    log_success "Subscription created: ${SUBSCRIPTION_NAME}"
}

wait_for_initial_sync() {
    log_info "Waiting for initial data sync to complete..."
    
    local max_wait=300  # 5 minutes
    local elapsed=0
    local interval=5
    
    while [ $elapsed -lt $max_wait ]; do
        local state=$(sudo -u postgres psql -d "${TARGET_DATABASE}" -t -c \
            "SELECT srsubstate FROM pg_subscription_rel WHERE srsubid = 
             (SELECT oid FROM pg_subscription WHERE subname='${SUBSCRIPTION_NAME}');" | xargs)
        
        if [ "$state" = "r" ]; then
            log_success "Initial sync completed"
            return 0
        fi
        
        log_info "Sync state: ${state}, waiting... (${elapsed}s/${max_wait}s)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_error "Initial sync did not complete within ${max_wait} seconds"
    exit 1
}

# ====================
# Phase 4: DDL Replication Automation
# ====================

create_ddl_replication_table() {
    log_info "Creating DDL replication log table..."
    
    local ddl_table_sql="
    CREATE TABLE IF NOT EXISTS ddl_replication_log (
        id SERIAL PRIMARY KEY,
        event_time TIMESTAMP DEFAULT NOW(),
        command_tag TEXT,
        object_type TEXT,
        schema_name TEXT,
        object_identity TEXT,
        ddl_command TEXT,
        processed BOOLEAN DEFAULT FALSE
    );"
    
    sudo -u postgres psql -d "${SOURCE_DATABASE}" -c "$ddl_table_sql"
    sudo -u postgres psql -d "${TARGET_DATABASE}" -c "$ddl_table_sql"
    
    log_success "DDL replication log tables created"
}

create_ddl_event_trigger() {
    log_info "Creating DDL event trigger in source database..."
    
    local trigger_function="
    CREATE OR REPLACE FUNCTION log_ddl_changes()
    RETURNS event_trigger AS \$\$
    DECLARE
        obj record;
    BEGIN
        FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands()
        LOOP
            INSERT INTO ddl_replication_log (command_tag, object_type, schema_name, object_identity, ddl_command)
            VALUES (TG_TAG, obj.object_type, obj.schema_name, obj.object_identity, current_query());
        END LOOP;
    END;
    \$\$ LANGUAGE plpgsql;"
    
    sudo -u postgres psql -d "${SOURCE_DATABASE}" -c "$trigger_function"
    
    # Drop existing trigger if it exists
    sudo -u postgres psql -d "${SOURCE_DATABASE}" -c "DROP EVENT TRIGGER IF EXISTS capture_ddl_changes;" 2>/dev/null || true
    
    local event_trigger="
    CREATE EVENT TRIGGER capture_ddl_changes
    ON ddl_command_end
    WHEN TAG IN ('ALTER TABLE', 'CREATE TABLE', 'DROP TABLE')
    EXECUTE FUNCTION log_ddl_changes();"
    
    sudo -u postgres psql -d "${SOURCE_DATABASE}" -c "$event_trigger"
    
    log_success "DDL event trigger created"
}

install_ddl_worker() {
    log_info "Installing DDL replication worker..."
    
    # Install Python dependencies
    apt-get update -qq
    apt-get install -y python3-pip python3-psycopg2 2>&1 | grep -v "^Reading\|^Building\|^Preparing\|^Unpacking\|^Setting up\|^Processing\|^Selecting\|^Get:" || true
    
    log_success "Python dependencies installed"
}

create_ddl_worker_script() {
    log_info "Creating DDL worker script..."
    
    cat > /usr/local/bin/replicate_ddl_changes.py << 'EOFPYTHON'
#!/usr/bin/env python3
"""
DDL Replication Worker
Monitors DDL changes in source database and replicates them to target database
"""

import psycopg2
import time
import logging
import sys
from datetime import datetime

# Configuration (will be replaced by script)
CONFIG = {
    'source_db': 'SOURCE_DATABASE_PLACEHOLDER',
    'target_db': 'TARGET_DATABASE_PLACEHOLDER',
    'postgres_password': 'POSTGRES_PASSWORD_PLACEHOLDER',
    'poll_interval': POLL_INTERVAL_PLACEHOLDER,
    'log_file': 'LOG_FILE_PLACEHOLDER'
}

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(CONFIG['log_file']),
        logging.StreamHandler(sys.stdout)
    ]
)

def get_db_connection(dbname):
    """Create PostgreSQL connection"""
    return psycopg2.connect(
        host='localhost',
        port=5432,
        dbname=dbname,
        user='postgres',
        password=CONFIG['postgres_password']
    )

def get_pending_ddl_changes(conn):
    """Get unprocessed DDL changes from source database"""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, command_tag, ddl_command 
            FROM ddl_replication_log 
            WHERE processed = FALSE 
            ORDER BY id ASC
        """)
        return cur.fetchall()

def apply_ddl_to_target(target_conn, ddl_command):
    """Apply DDL command to target database"""
    with target_conn.cursor() as cur:
        cur.execute(ddl_command)
    target_conn.commit()

def mark_ddl_processed(source_conn, ddl_id):
    """Mark DDL change as processed"""
    with source_conn.cursor() as cur:
        cur.execute(
            "UPDATE ddl_replication_log SET processed = TRUE WHERE id = %s",
            (ddl_id,)
        )
    source_conn.commit()

def main():
    """Main worker loop"""
    logging.info("DDL Replication Worker started")
    logging.info(f"Source DB: {CONFIG['source_db']}, Target DB: {CONFIG['target_db']}")
    logging.info(f"Poll interval: {CONFIG['poll_interval']} seconds")
    
    while True:
        try:
            # Connect to databases
            source_conn = get_db_connection(CONFIG['source_db'])
            target_conn = get_db_connection(CONFIG['target_db'])
            
            # Get pending DDL changes
            pending_changes = get_pending_ddl_changes(source_conn)
            
            if pending_changes:
                logging.info(f"Found {len(pending_changes)} pending DDL change(s)")
                
                for ddl_id, command_tag, ddl_command in pending_changes:
                    try:
                        logging.info(f"Applying DDL (ID: {ddl_id}, Tag: {command_tag})...")
                        logging.debug(f"DDL Command: {ddl_command}")
                        
                        apply_ddl_to_target(target_conn, ddl_command)
                        mark_ddl_processed(source_conn, ddl_id)
                        
                        logging.info(f"DDL {ddl_id} successfully replicated")
                    except Exception as e:
                        logging.error(f"Failed to replicate DDL {ddl_id}: {e}")
                        # Continue with next DDL instead of stopping
            
            # Close connections
            source_conn.close()
            target_conn.close()
            
            # Wait before next check
            time.sleep(CONFIG['poll_interval'])
            
        except KeyboardInterrupt:
            logging.info("DDL Replication Worker stopped by user")
            break
        except Exception as e:
            logging.error(f"Error in main loop: {e}")
            time.sleep(CONFIG['poll_interval'])

if __name__ == '__main__':
    main()
EOFPYTHON
    
    # Replace placeholders with actual values
    sed -i "s/SOURCE_DATABASE_PLACEHOLDER/${SOURCE_DATABASE}/g" /usr/local/bin/replicate_ddl_changes.py
    sed -i "s/TARGET_DATABASE_PLACEHOLDER/${TARGET_DATABASE}/g" /usr/local/bin/replicate_ddl_changes.py
    sed -i "s/POSTGRES_PASSWORD_PLACEHOLDER/${POSTGRES_PASSWORD}/g" /usr/local/bin/replicate_ddl_changes.py
    sed -i "s/POLL_INTERVAL_PLACEHOLDER/${DDL_POLL_INTERVAL_SECONDS}/g" /usr/local/bin/replicate_ddl_changes.py
    sed -i "s|LOG_FILE_PLACEHOLDER|${DDL_LOG_FILE}|g" /usr/local/bin/replicate_ddl_changes.py
    
    chmod +x /usr/local/bin/replicate_ddl_changes.py
    
    log_success "DDL worker script created"
}

create_ddl_worker_service() {
    log_info "Creating systemd service for DDL worker..."
    
    cat > /etc/systemd/system/ddl-replication-worker.service << EOF
[Unit]
Description=PostgreSQL DDL Replication Worker
After=postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/replicate_ddl_changes.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable ddl-replication-worker
    systemctl start ddl-replication-worker
    
    DDL_WORKER_INSTALLED=true
    log_success "DDL worker service created and started"
}

# ====================
# Phase 5: Vector Embedding Automation
# ====================

install_plpython3u() {
    log_info "Installing plpython3u extension..."
    
    apt-get install -y "postgresql-plpython3-${DETECTED_PG_VERSION}" 2>&1 | grep -v "^Reading\|^Building\|^Preparing\|^Unpacking\|^Setting up\|^Processing\|^Selecting\|^Get:" || true
    
    sudo -u postgres psql -d "${TARGET_DATABASE}" -c "CREATE EXTENSION IF NOT EXISTS plpython3u;"
    
    log_success "plpython3u extension installed"
    
    # Install Python requests library
    log_info "Installing Python requests library..."
    pip3 install --quiet requests
    log_success "Python requests library installed"
}

create_embedding_function() {
    log_info "Creating embedding generation function..."
    
    # Set Ollama API URL in database configuration
    sudo -u postgres psql -d "${TARGET_DATABASE}" -c \
        "ALTER DATABASE ${TARGET_DATABASE} SET app.ollama_api_url = '${OLLAMA_API_URL}';"
    
    local embedding_function="
    CREATE OR REPLACE FUNCTION generate_embedding(text_input TEXT)
    RETURNS vector(${EMBEDDING_DIMENSION}) AS \$\$
        import requests
        import json
        
        if not text_input:
            return None
            
        # Truncate text if too long
        max_length = ${MAX_TEXT_LENGTH}
        if len(text_input) > max_length:
            text_input = text_input[:max_length]
        
        ollama_url = plpy.execute(\"SHOW app.ollama_api_url\")[0][\"app.ollama_api_url\"]
        endpoint = f\"{ollama_url}/api/embeddings\"
        
        payload = {
            \"model\": \"${OLLAMA_MODEL}\",
            \"prompt\": text_input
        }
        
        try:
            response = requests.post(endpoint, json=payload, timeout=30)
            if response.status_code == 200:
                return response.json()['embedding']
            else:
                plpy.warning(f\"Ollama API error: {response.status_code} - {response.text}\")
                return None
        except Exception as e:
            plpy.warning(f\"Failed to generate embedding: {str(e)}\")
            return None
    \$\$ LANGUAGE plpython3u;"
    
    sudo -u postgres psql -d "${TARGET_DATABASE}" -c "$embedding_function"
    
    log_success "Embedding generation function created"
}

create_embedding_trigger() {
    log_info "Creating trigger for automatic embedding generation..."
    
    local vector_col_name="${TEXT_COLUMN_TO_VECTORIZE}_embedding"
    
    local trigger_function="
    CREATE OR REPLACE FUNCTION auto_generate_embeddings()
    RETURNS TRIGGER AS \$\$
    BEGIN
        IF NEW.${TEXT_COLUMN_TO_VECTORIZE} IS NOT NULL AND NEW.${vector_col_name} IS NULL THEN
            NEW.${vector_col_name} = generate_embedding(NEW.${TEXT_COLUMN_TO_VECTORIZE});
        END IF;
        RETURN NEW;
    END;
    \$\$ LANGUAGE plpgsql;"
    
    sudo -u postgres psql -d "${TARGET_DATABASE}" -c "$trigger_function"
    
    # Drop existing trigger if it exists
    sudo -u postgres psql -d "${TARGET_DATABASE}" -c \
        "DROP TRIGGER IF EXISTS embeddings_on_insert_update ON ${SOURCE_TABLE};" 2>/dev/null || true
    
    local trigger="
    CREATE TRIGGER embeddings_on_insert_update
    BEFORE INSERT OR UPDATE ON ${SOURCE_TABLE}
    FOR EACH ROW EXECUTE FUNCTION auto_generate_embeddings();"
    
    sudo -u postgres psql -d "${TARGET_DATABASE}" -c "$trigger"
    
    EMBEDDINGS_CONFIGURED=true
    log_success "Embedding trigger created"
}

backfill_embeddings() {
    log_info "Backfilling embeddings for existing data..."
    log_warning "This may take a while depending on the number of rows..."
    
    local vector_col_name="${TEXT_COLUMN_TO_VECTORIZE}_embedding"
    
    local backfill_script="
    DO \$\$
    DECLARE
        batch_size INT := ${EMBEDDING_BATCH_SIZE};
        updated_count INT;
        total_updated INT := 0;
    BEGIN
        LOOP
            UPDATE ${SOURCE_TABLE} 
            SET ${vector_col_name} = generate_embedding(${TEXT_COLUMN_TO_VECTORIZE})
            WHERE id IN (
                SELECT id FROM ${SOURCE_TABLE} 
                WHERE ${TEXT_COLUMN_TO_VECTORIZE} IS NOT NULL 
                AND ${vector_col_name} IS NULL
                LIMIT batch_size
            );
            
            GET DIAGNOSTICS updated_count = ROW_COUNT;
            EXIT WHEN updated_count = 0;
            
            total_updated := total_updated + updated_count;
            RAISE NOTICE 'Progress: % rows processed', total_updated;
            
            PERFORM pg_sleep(${EMBEDDING_THROTTLE_SECONDS});
        END LOOP;
        
        RAISE NOTICE 'Backfill complete: % total rows updated', total_updated;
    END \$\$;"
    
    sudo -u postgres psql -d "${TARGET_DATABASE}" -c "$backfill_script"
    
    log_success "Embedding backfill completed"
}

# ====================
# Phase 6: Monitoring Integration
# ====================

install_postgres_exporter() {
    log_info "Installing postgres_exporter..."
    
    # Download latest postgres_exporter
    local exporter_version="0.15.0"
    local download_url="https://github.com/prometheus-community/postgres_exporter/releases/download/v${exporter_version}/postgres_exporter-${exporter_version}.linux-amd64.tar.gz"
    
    cd /tmp
    wget -q "${download_url}" -O postgres_exporter.tar.gz
    tar -xzf postgres_exporter.tar.gz
    mv postgres_exporter-*/postgres_exporter /usr/local/bin/
    chmod +x /usr/local/bin/postgres_exporter
    rm -rf postgres_exporter*
    
    log_success "postgres_exporter installed"
}

create_postgres_exporter_config() {
    log_info "Creating postgres_exporter configuration..."
    
    mkdir -p /etc/postgres_exporter
    
    cat > /etc/postgres_exporter/queries.yaml << EOF
pg_replication_lag:
  query: "SELECT COALESCE(EXTRACT(epoch FROM (now() - last_msg_send_time)), 0) as lag_seconds FROM pg_stat_subscription WHERE subname = '${SUBSCRIPTION_NAME}';"
  metrics:
    - lag_seconds:
        usage: "GAUGE"
        description: "Replication lag in seconds for ${SUBSCRIPTION_NAME}"

pg_replication_slot_status:
  query: "SELECT CASE WHEN active THEN 1 ELSE 0 END as active FROM pg_replication_slots WHERE slot_name = '${SUBSCRIPTION_NAME}';"
  metrics:
    - active:
        usage: "GAUGE"
        description: "Replication slot active status (1=active, 0=inactive)"
EOF
    
    log_success "postgres_exporter configuration created"
}

create_postgres_exporter_service() {
    log_info "Creating systemd service for postgres_exporter..."
    
    # Construct DSN if not provided
    if [ -z "${PROMETHEUS_DSN}" ]; then
        PROMETHEUS_DSN="postgresql://postgres:${POSTGRES_PASSWORD}@localhost:5432/postgres?sslmode=disable"
    fi
    
    cat > /etc/systemd/system/postgres_exporter.service << EOF
[Unit]
Description=Prometheus PostgreSQL Exporter
After=postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=postgres
Environment="DATA_SOURCE_NAME=${PROMETHEUS_DSN}"
ExecStart=/usr/local/bin/postgres_exporter --web.listen-address=:${PROMETHEUS_PORT} --extend.query-path=/etc/postgres_exporter/queries.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable postgres_exporter
    systemctl start postgres_exporter
    
    MONITORING_INSTALLED=true
    log_success "postgres_exporter service created and started"
}

# ====================
# Phase 7: Verification
# ====================

verify_replication() {
    log_info "Verifying replication setup..."
    
    # Check publication
    local pub_count=$(sudo -u postgres psql -d "${SOURCE_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM pg_publication WHERE pubname='${PUBLICATION_NAME}';")
    
    if [ "$pub_count" -eq 0 ]; then
        log_error "Publication verification failed"
        return 1
    fi
    
    # Check subscription
    local sub_count=$(sudo -u postgres psql -d "${TARGET_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM pg_stat_subscription WHERE subname='${SUBSCRIPTION_NAME}' AND pid IS NOT NULL;")
    
    if [ "$sub_count" -eq 0 ]; then
        log_error "Subscription verification failed - worker not running"
        return 1
    fi
    
    # Check row counts match
    local source_count=$(sudo -u postgres psql -d "${SOURCE_DATABASE}" -t -c "SELECT COUNT(*) FROM ${SOURCE_TABLE};" | xargs)
    local target_count=$(sudo -u postgres psql -d "${TARGET_DATABASE}" -t -c "SELECT COUNT(*) FROM ${SOURCE_TABLE};" | xargs)
    
    if [ "$source_count" != "$target_count" ]; then
        log_warning "Row counts differ: Source=$source_count, Target=$target_count"
        log_info "This may be normal if sync is still in progress"
    else
        log_success "Row counts match: ${source_count} rows"
    fi
    
    log_success "Replication verification passed"
}

verify_ddl_replication() {
    if [ "${ENABLE_DDL_REPLICATION}" != "yes" ]; then
        return 0
    fi
    
    log_info "Verifying DDL replication..."
    
    # Check DDL worker service
    if ! systemctl is-active --quiet ddl-replication-worker; then
        log_error "DDL worker service is not running"
        return 1
    fi
    
    log_success "DDL replication verification passed"
}

verify_embeddings() {
    if [ "${ENABLE_EMBEDDING_GENERATION}" != "yes" ]; then
        return 0
    fi
    
    log_info "Verifying embedding generation..."
    
    local vector_col_name="${TEXT_COLUMN_TO_VECTORIZE}_embedding"
    
    # Check if function exists
    local func_exists=$(sudo -u postgres psql -d "${TARGET_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM pg_proc WHERE proname='generate_embedding';")
    
    if [ "$func_exists" -eq 0 ]; then
        log_error "Embedding function not found"
        return 1
    fi
    
    # Check if trigger exists
    local trigger_exists=$(sudo -u postgres psql -d "${TARGET_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM pg_trigger WHERE tgname='embeddings_on_insert_update';")
    
    if [ "$trigger_exists" -eq 0 ]; then
        log_error "Embedding trigger not found"
        return 1
    fi
    
    # Check if some embeddings were generated
    local embedding_count=$(sudo -u postgres psql -d "${TARGET_DATABASE}" -t -c \
        "SELECT COUNT(*) FROM ${SOURCE_TABLE} WHERE ${vector_col_name} IS NOT NULL;" | xargs)
    
    log_info "Rows with embeddings: ${embedding_count}"
    
    log_success "Embedding generation verification passed"
}

verify_monitoring() {
    if [ "${ENABLE_PROMETHEUS_MONITORING}" != "yes" ]; then
        return 0
    fi
    
    log_info "Verifying monitoring setup..."
    
    # Check if postgres_exporter is running
    if ! systemctl is-active --quiet postgres_exporter; then
        log_error "postgres_exporter service is not running"
        return 1
    fi
    
    # Check if metrics endpoint is accessible
    if ! curl -s "http://localhost:${PROMETHEUS_PORT}/metrics" > /dev/null; then
        log_error "Cannot access postgres_exporter metrics endpoint"
        return 1
    fi
    
    log_success "Monitoring verification passed"
}

run_verification_tests() {
    if [ "${RUN_VERIFICATION_TESTS}" != "yes" ]; then
        log_info "Verification tests skipped (RUN_VERIFICATION_TESTS=no)"
        return 0
    fi
    
    log_info "Running comprehensive verification tests..."
    
    verify_replication
    verify_ddl_replication
    verify_embeddings
    verify_monitoring
    
    log_success "All verification tests passed!"
}

# ====================
# Information Display
# ====================

display_completion_info() {
    echo ""
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}  CDC Replication Setup Completed Successfully!${NC}"
    echo -e "${GREEN}=============================================================================${NC}"
    echo ""
    echo "Configuration Summary:"
    echo "  Source Database:       ${SOURCE_DATABASE}"
    echo "  Target Database:       ${TARGET_DATABASE}"
    echo "  Replicated Table:      ${SOURCE_TABLE}"
    echo "  Publication:           ${PUBLICATION_NAME}"
    echo "  Subscription:          ${SUBSCRIPTION_NAME}"
    echo ""
    echo "Ollama Configuration:"
    echo "  API URL:               ${OLLAMA_API_URL}"
    echo "  Model:                 ${OLLAMA_MODEL}"
    echo "  Embedding Dimension:   ${EMBEDDING_DIMENSION}"
    echo ""
    echo "Features Enabled:"
    echo "  Logical Replication:   ✓ Yes"
    echo "  DDL Replication:       $([ "${ENABLE_DDL_REPLICATION}" = "yes" ] && echo "✓ Yes" || echo "✗ No")"
    echo "  Auto Embeddings:       $([ "${ENABLE_EMBEDDING_GENERATION}" = "yes" ] && echo "✓ Yes" || echo "✗ No")"
    echo "  Prometheus Monitoring: $([ "${ENABLE_PROMETHEUS_MONITORING}" = "yes" ] && echo "✓ Yes (port ${PROMETHEUS_PORT})" || echo "✗ No")"
    echo ""
    echo "Useful Commands:"
    echo "  Check replication status:"
    echo "    sudo -u postgres psql -d ${TARGET_DATABASE} -c \"SELECT * FROM pg_stat_subscription;\""
    echo ""
    echo "  Check replication lag:"
    echo "    sudo -u postgres psql -d ${TARGET_DATABASE} -c \"SELECT now() - last_msg_send_time as lag FROM pg_stat_subscription;\""
    echo ""
    echo "  Test semantic search (example):"
    echo "    sudo -u postgres psql -d ${TARGET_DATABASE} -c \"SELECT * FROM ${SOURCE_TABLE} ORDER BY ${TEXT_COLUMN_TO_VECTORIZE}_embedding <-> generate_embedding('your search query') LIMIT 5;\""
    echo ""
    if [ "${ENABLE_DDL_REPLICATION}" = "yes" ]; then
        echo "  Check DDL worker status:"
        echo "    sudo systemctl status ddl-replication-worker"
        echo "    tail -f ${DDL_LOG_FILE}"
        echo ""
    fi
    if [ "${ENABLE_PROMETHEUS_MONITORING}" = "yes" ]; then
        echo "  View Prometheus metrics:"
        echo "    curl http://localhost:${PROMETHEUS_PORT}/metrics | grep pg_replication"
        echo ""
    fi
    echo "Log file: ${LOG_FILE}"
    echo ""
    echo -e "${GREEN}=============================================================================${NC}"
}

# ====================
# Main Function
# ====================

main() {
    display_banner
    
    # Pre-flight checks
    check_root
    check_ubuntu_version
    load_config
    check_postgresql
    detect_pg_version
    check_source_database
    
    if [ "${ENABLE_EMBEDDING_GENERATION}" = "yes" ]; then
        check_ollama
    fi
    
    INSTALLATION_STARTED=true
    
    # Phase 1: PostgreSQL Configuration
    log_info "=== Phase 1: PostgreSQL Configuration ==="
    backup_postgresql_config
    configure_logical_replication
    
    # Phase 2: Target Database Setup
    log_info "=== Phase 2: Target Database Setup ==="
    create_target_database
    enable_pgvector_extension
    replicate_table_schema
    add_vector_column
    
    # Phase 3: Logical Replication Setup
    log_info "=== Phase 3: Logical Replication Setup ==="
    create_publication
    create_subscription
    wait_for_initial_sync
    
    # Phase 4: DDL Replication Automation
    if [ "${ENABLE_DDL_REPLICATION}" = "yes" ]; then
        log_info "=== Phase 4: DDL Replication Automation ==="
        create_ddl_replication_table
        create_ddl_event_trigger
        install_ddl_worker
        create_ddl_worker_script
        create_ddl_worker_service
    else
        log_info "=== Phase 4: DDL Replication Automation (SKIPPED) ==="
    fi
    
    # Phase 5: Vector Embedding Automation
    if [ "${ENABLE_EMBEDDING_GENERATION}" = "yes" ]; then
        log_info "=== Phase 5: Vector Embedding Automation ==="
        install_plpython3u
        create_embedding_function
        create_embedding_trigger
        backfill_embeddings
    else
        log_info "=== Phase 5: Vector Embedding Automation (SKIPPED) ==="
    fi
    
    # Phase 6: Monitoring Integration
    if [ "${ENABLE_PROMETHEUS_MONITORING}" = "yes" ]; then
        log_info "=== Phase 6: Monitoring Integration ==="
        install_postgres_exporter
        create_postgres_exporter_config
        create_postgres_exporter_service
    else
        log_info "=== Phase 6: Monitoring Integration (SKIPPED) ==="
    fi
    
    # Phase 7: Verification
    log_info "=== Phase 7: Verification ==="
    run_verification_tests
    
    # Display completion information
    display_completion_info
}

# Run main function
main
