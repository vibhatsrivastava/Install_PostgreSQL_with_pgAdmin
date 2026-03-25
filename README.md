# PostgreSQL and pgAdmin4 Installation for Ubuntu 24.04

Automated installation script for PostgreSQL database server and pgAdmin4 web interface on Ubuntu 24.04 LTS.

## Features

- ✅ Automated PostgreSQL installation and configuration
- ✅ pgAdmin4 Web interface setup
- ✅ Custom database and user creation
- ✅ Optional remote access configuration
- ✅ **Intelligent performance tuning with auto-detection**
- ✅ **SSD/HDD disk type optimization**
- ✅ **Apache reverse proxy with custom domain support (optional)**
- ✅ **Self-signed SSL certificate generation for HTTPS (optional)**
- ✅ Comprehensive error handling with rollback capability
- ✅ Detailed logging for troubleshooting
- ✅ Pre-installation checks to prevent conflicts

## Prerequisites

- **Operating System**: Ubuntu 24.04 LTS (tested on this version)
- **Privileges**: Root or sudo access
- **Internet Connection**: Required to download packages
- **Disk Space**: At least 500MB free space

## Quick Start

### 1. Clone or Download

```bash
git clone <repository-url>
cd Install_PostgreSQL_with_pgAdmin
```

### 2. Configure Installation

Edit the `install_config.conf` file with your desired settings:

```bash
nano install_config.conf
```

**Important settings to configure:**

- `POSTGRES_PASSWORD`: Password for the postgres superuser (min 8 characters)
- `PGADMIN_EMAIL`: Email address for pgAdmin login
- `PGADMIN_PASSWORD`: Password for pgAdmin web interface (min 6 characters)
- `CUSTOM_USERNAME`: Your custom database user name
- `CUSTOM_USER_PASSWORD`: Password for your custom user
- `CUSTOM_DATABASE_NAME`: Name of your custom database
- `ENABLE_REMOTE_ACCESS`: Set to "yes" to allow remote connections
- `APPLY_PERFORMANCE_TUNING`: Set to "yes" to optimize PostgreSQL performance
- `PERFORMANCE_PROFILE`: Choose "auto", "low", "medium", "high", or "custom"

### 3. Secure Configuration File

```bash
chmod 600 install_config.conf
```

### 4. Run Installation Script

```bash
chmod +x install_postgresql_pgadmin.sh
sudo ./install_postgresql_pgadmin.sh
```

The script will:
- Validate your system and configuration
- Check for existing installations
- Install PostgreSQL and pgAdmin4
- Configure databases and users
- Set up remote access (if enabled)
- Verify the installation
- Display connection information

## Configuration Options

### PostgreSQL Settings

| Option | Description | Default |
|--------|-------------|---------|
| `POSTGRES_PASSWORD` | Postgres superuser password | ChangeMe123! |
| `POSTGRES_VERSION` | Specific version to install | (latest) |

### Custom Database User

| Option | Description | Default |
|--------|-------------|---------|
| `CREATE_CUSTOM_USER` | Create a custom user | yes |
| `CUSTOM_USERNAME` | Username for custom user | dbuser |
| `CUSTOM_USER_PASSWORD` | Password for custom user | SecurePass456! |

### Custom Database

| Option | Description | Default |
|--------|-------------|---------|
| `CREATE_CUSTOM_DATABASE` | Create a custom database | yes |
| `CUSTOM_DATABASE_NAME` | Database name | myappdb |
| `CUSTOM_DATABASE_OWNER` | Database owner | dbuser |

### Remote Access

| Option | Description | Default |
|--------|-------------|---------|
| `ENABLE_REMOTE_ACCESS` | Allow remote connections | no |
| `ALLOWED_IP_RANGE` | CIDR range for allowed IPs | 0.0.0.0/0 |
### Performance Tuning

| Option | Description | Default |
|--------|-------------|------|
| `APPLY_PERFORMANCE_TUNING` | Enable performance optimization | yes |
| `PERFORMANCE_PROFILE` | Profile: auto, low, medium, high, custom | auto |
| `CUSTOM_SHARED_BUFFERS` | PostgreSQL shared buffers (custom only) | (auto) |
| `CUSTOM_EFFECTIVE_CACHE_SIZE` | Effective cache size (custom only) | (auto) |
| `CUSTOM_MAINTENANCE_WORK_MEM` | Maintenance work memory (custom only) | (auto) |
| `CUSTOM_WORK_MEM` | Work memory per operation (custom only) | (auto) |
| `CUSTOM_MAX_CONNECTIONS` | Maximum connections (custom only) | (auto) |
| `CUSTOM_MAX_WAL_SIZE` | Maximum WAL size (custom only) | (auto) |
| `CUSTOM_MIN_WAL_SIZE` | Minimum WAL size (custom only) | (auto) |
| `CUSTOM_CHECKPOINT_COMPLETION_TARGET` | Checkpoint completion (custom only) | 0.9 |
| `CUSTOM_WAL_BUFFERS` | WAL buffers (custom only) | 16MB |
| `CUSTOM_DEFAULT_STATISTICS_TARGET` | Statistics target (custom only) | 100 |
| `CUSTOM_RANDOM_PAGE_COST` | Random page cost (custom only) | (auto: 1.1 SSD, 4.0 HDD) |
| `CUSTOM_EFFECTIVE_IO_CONCURRENCY` | IO concurrency (custom only) | (auto: 200 SSD, 2 HDD) |
### pgAdmin Settings

| Option | Description | Default |
|--------|-------------|---------|
| `PGADMIN_EMAIL` | pgAdmin login email | admin@example.com |
| `PGADMIN_PASSWORD` | pgAdmin login password | Admin123! |

## Accessing PostgreSQL

### Local Connection (Command Line)

Connect as postgres superuser:
```bash
sudo -u postgres psql
```

Connect as custom user:
```bash
psql -U dbuser -d myappdb -h localhost
# Enter password when prompted
```

### Remote Connection

If remote access is enabled:
```bash
psql -h <server-ip> -U dbuser -d myappdb
```

### Connection String Format

```
postgresql://username:password@host:5432/database
```

Example:
```
postgresql://dbuser:SecurePass456!@localhost:5432/myappdb
```

## Accessing pgAdmin4

### Local Access

Open your web browser and navigate to:
```
http://localhost/pgadmin4
```

### Remote Access

From another computer on the network:
```
http://<server-ip>/pgadmin4
```

**Login credentials:**
- Email: (as configured in `PGADMIN_EMAIL`)
- Password: (as configured in `PGADMIN_PASSWORD`)

### Adding PostgreSQL Server in pgAdmin

1. Login to pgAdmin4
2. Click "Add New Server"
3. General tab:
   - Name: My PostgreSQL Server
4. Connection tab:
   - Host: localhost (or server IP for remote)
   - Port: 5432
   - Username: postgres (or your custom username)
   - Password: (your configured password)
5. Click "Save"

## Performance Tuning

The installation script includes intelligent performance tuning that automatically optimizes PostgreSQL based on your system's hardware.

### How It Works

1. **Auto-Detection**: The script automatically detects:
   - Total system RAM
   - Number of CPU cores
   - Disk type (SSD vs HDD)

2. **Profile Selection**: Based on detected resources, it selects an optimal profile:
   - **low**: For systems with 1-2GB RAM
   - **medium**: For systems with 2-8GB RAM
   - **high**: For systems with 8GB+ RAM

3. **Optimization**: Applies 11 PostgreSQL parameters optimized for your hardware

### Performance Profiles

#### Auto Profile (Recommended)

Automatically selects the best profile based on available RAM:

```bash
PERFORMANCE_PROFILE="auto"
```

#### Low Profile (1-2GB RAM)

Optimized for smaller systems and light workloads:
- shared_buffers: 256MB
- effective_cache_size: 1GB
- work_mem: 4MB
- max_connections: 100

```bash
PERFORMANCE_PROFILE="low"
```

#### Medium Profile (4-8GB RAM)

Balanced settings for typical applications:
- shared_buffers: 1GB
- effective_cache_size: 3GB
- work_mem: 16MB
- max_connections: 200

```bash
PERFORMANCE_PROFILE="medium"
```

#### High Profile (8GB+ RAM)

Maximum performance for high-traffic applications:
- shared_buffers: 25% of total RAM
- effective_cache_size: 75% of total RAM
- work_mem: 32MB
- max_connections: 300

```bash
PERFORMANCE_PROFILE="high"
```

#### Custom Profile

Fine-tune individual parameters:

```bash
PERFORMANCE_PROFILE="custom"
CUSTOM_SHARED_BUFFERS="2GB"
CUSTOM_EFFECTIVE_CACHE_SIZE="6GB"
CUSTOM_WORK_MEM="16MB"
CUSTOM_MAX_CONNECTIONS="150"
# ... additional custom parameters
```

### SSD vs HDD Optimization

The script automatically detects your disk type and optimizes:

**SSD Optimization:**
- `random_page_cost = 1.1` (default: 4.0)
- `effective_io_concurrency = 200` (default: 2)

**HDD Optimization:**
- `random_page_cost = 4.0`
- `effective_io_concurrency = 2`

### Parameters Optimized

The performance tuning adjusts these PostgreSQL parameters:

1. **Memory Settings:**
   - `shared_buffers`: PostgreSQL's shared memory buffer pool
   - `effective_cache_size`: OS and PostgreSQL cache estimation
   - `maintenance_work_mem`: Memory for maintenance operations
   - `work_mem`: Memory for query operations

2. **Connection Settings:**
   - `max_connections`: Maximum concurrent connections

3. **Write-Ahead Log (WAL):**
   - `max_wal_size`: Maximum WAL size before checkpoint
   - `min_wal_size`: Minimum WAL size to maintain
   - `checkpoint_completion_target`: Checkpoint timing
   - `wal_buffers`: WAL buffer size

4. **Query Planner:**
   - `default_statistics_target`: Query planning statistics detail
   - `random_page_cost`: Cost estimate for random disk operations
   - `effective_io_concurrency`: Concurrent I/O operations

### Verifying Performance Settings

After installation, verify the applied settings:

```bash
# Connect to PostgreSQL
sudo -u postgres psql

# Check specific parameter
SHOW shared_buffers;
SHOW effective_cache_size;
SHOW max_connections;

# Show all settings
SHOW ALL;

# Exit
\q
```

### Disabling Performance Tuning

To install with default PostgreSQL settings:

```bash
APPLY_PERFORMANCE_TUNING="no"
```

### Performance Tuning for Specific Use Cases

#### High-Volume Inserts (e.g., Ansible Job Logging)

For applications with hundreds of concurrent inserts:

```bash
PERFORMANCE_PROFILE="custom"
CUSTOM_SHARED_BUFFERS="2GB"
CUSTOM_WORK_MEM="16MB"
CUSTOM_MAX_CONNECTIONS="300"          # High concurrent connections
CUSTOM_MAX_WAL_SIZE="4GB"             # Larger WAL for write-heavy loads
CUSTOM_CHECKPOINT_COMPLETION_TARGET="0.9"  # Smooth checkpoints
```

Additionally, consider:
- Using connection pooling (pgBouncer)
- Implementing table partitioning for large tables
- Batch inserts (100-500 rows per INSERT statement)

#### Read-Heavy Applications

```bash
PERFORMANCE_PROFILE="custom"
CUSTOM_SHARED_BUFFERS="4GB"
CUSTOM_EFFECTIVE_CACHE_SIZE="12GB"
CUSTOM_WORK_MEM="32MB"
CUSTOM_MAX_CONNECTIONS="100"
```

#### Mixed Workloads

```bash
PERFORMANCE_PROFILE="auto"  # Recommended for most cases
```

## Apache Reverse Proxy Setup (Optional)

After installing PostgreSQL and pgAdmin, you can optionally configure Apache as a reverse proxy to access pgAdmin through a custom local domain (e.g., `postgresql.local`) with optional SSL support.

### Why Use a Reverse Proxy?

- **Custom Domain**: Access pgAdmin with a friendly domain name instead of IP addresses
- **SSL/HTTPS**: Secure your pgAdmin access with self-signed certificates
- **Professional Setup**: Mimics production-like environments for development
- **Easier Access**: Remember `https://postgresql.local` instead of `http://192.168.1.x/pgadmin4`

### Prerequisites

Before running the reverse proxy setup:

1. ✅ PostgreSQL and pgAdmin must be already installed (run `install_postgresql_pgadmin.sh` first)
2. ✅ Apache must be running
3. ✅ Root/sudo privileges

### Installation Steps

#### 1. Configure Reverse Proxy Settings

Edit the `install_config_proxy.conf` file:

```bash
nano install_config_proxy.conf
```

**Key settings:**

```bash
# Domain name for local access
DOMAIN_NAME="postgresql.local"

# Enable SSL with self-signed certificate
ENABLE_SSL="yes"

# SSL certificate details
SSL_COUNTRY="US"
SSL_STATE="California"
SSL_CITY="San Francisco"
SSL_ORG="Development"
```

#### 2. Secure Configuration File

```bash
chmod 600 install_config_proxy.conf
```

#### 3. Run the Reverse Proxy Setup Script

```bash
chmod +x install_apache_reverse_proxy.sh
sudo ./install_apache_reverse_proxy.sh
```

The script will:
- Check that PostgreSQL and pgAdmin are installed and running
- Enable required Apache modules (proxy, ssl, headers)
- Generate a self-signed SSL certificate (if enabled)
- Create Apache VirtualHost configuration
- Add the domain to `/etc/hosts`
- Verify the reverse proxy is working

### Reverse Proxy Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `DOMAIN_NAME` | Local domain name | postgresql.local |
| `ENABLE_SSL` | Enable HTTPS with self-signed cert | yes |
| `SSL_COUNTRY` | Certificate country code | US |
| `SSL_STATE` | Certificate state/province | California |
| `SSL_CITY` | Certificate city | San Francisco |
| `SSL_ORG` | Certificate organization | Development |
| `SSL_DAYS_VALID` | Certificate validity in days | 365 |
| `APACHE_CONFIG_NAME` | VirtualHost config file name | pgadmin-proxy |
| `HTTP_PORT` | HTTP port | 80 |
| `HTTPS_PORT` | HTTPS port | 443 |

### Accessing pgAdmin Through Reverse Proxy

#### With SSL (HTTPS)

Open your browser and navigate to:
```
https://postgresql.local/
```

**⚠️ Certificate Warning**: Your browser will show a security warning because the SSL certificate is self-signed. This is normal for local development. Click "Advanced" or "Proceed" to continue.

#### Without SSL (HTTP)

```
http://postgresql.local/
```

**Login credentials**: Use the same pgAdmin credentials you configured in the main installation:
- Email: (as configured in `PGADMIN_EMAIL`)
- Password: (as configured in `PGADMIN_PASSWORD`)

### SSL Certificate Information

When `ENABLE_SSL="yes"`, the script generates a self-signed SSL certificate:

- **Certificate location**: `/etc/apache2/ssl/postgresql.local/postgresql.local.crt`
- **Private key location**: `/etc/apache2/ssl/postgresql.local/postgresql.local.key`
- **Validity**: 365 days by default (configurable)

#### Accepting Self-Signed Certificates

**Chrome/Edge:**
1. When you see the warning, click "Advanced"
2. Click "Proceed to postgresql.local (unsafe)"

**Firefox:**
1. Click "Advanced"
2. Click "Accept the Risk and Continue"

**For permanent trust** (optional):
```bash
# Export the certificate
sudo cp /etc/apache2/ssl/postgresql.local/postgresql.local.crt ~/

# Import to system trust store (Ubuntu)
sudo cp /etc/apache2/ssl/postgresql.local/postgresql.local.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### Reverse Proxy Useful Commands

```bash
# Check Apache virtual host configuration
sudo apache2ctl -S

# View reverse proxy access logs
sudo tail -f /var/log/apache2/pgadmin-proxy_access.log

# View SSL access logs
sudo tail -f /var/log/apache2/pgadmin-proxy_ssl_access.log

# Test configuration
sudo apache2ctl configtest

# Reload Apache after manual config changes
sudo systemctl reload apache2

# Disable reverse proxy
sudo a2dissite pgadmin-proxy
sudo systemctl reload apache2

# Re-enable reverse proxy
sudo a2ensite pgadmin-proxy
sudo systemctl reload apache2
```

### Reverse Proxy Troubleshooting

#### Domain Not Resolving

1. Check `/etc/hosts` file:
   ```bash
   cat /etc/hosts | grep postgresql.local
   ```
   Should show: `127.0.0.1    postgresql.local`

2. If missing, add manually:
   ```bash
   echo "127.0.0.1    postgresql.local" | sudo tee -a /etc/hosts
   ```

#### SSL Certificate Errors

1. Verify certificate files exist:
   ```bash
   ls -la /etc/apache2/ssl/postgresql.local/
   ```

2. Check certificate details:
   ```bash
   openssl x509 -in /etc/apache2/ssl/postgresql.local/postgresql.local.crt -text -noout
   ```

3. Verify Apache SSL module is enabled:
   ```bash
   apache2ctl -M | grep ssl
   ```

#### Proxy Not Working

1. Check if proxy modules are enabled:
   ```bash
   apache2ctl -M | grep proxy
   ```
   Should show: `proxy_module`, `proxy_http_module`

2. Check VirtualHost configuration:
   ```bash
   sudo nano /etc/apache2/sites-available/pgadmin-proxy.conf
   ```

3. Test Apache configuration:
   ```bash
   sudo apache2ctl configtest
   ```

4. Check if site is enabled:
   ```bash
   ls -la /etc/apache2/sites-enabled/ | grep pgadmin-proxy
   ```

#### Getting HTTP 503 or 502 Errors

1. Ensure pgAdmin is running on Apache:
   ```bash
   curl -I http://127.0.0.1/pgadmin4/
   ```

2. Check Apache error logs:
   ```bash
   sudo tail -f /var/log/apache2/pgadmin-proxy_error.log
   ```

### Removal of Reverse Proxy

To remove the reverse proxy configuration:

```bash
# Disable the site
sudo a2dissite pgadmin-proxy

# Remove configuration file
sudo rm /etc/apache2/sites-available/pgadmin-proxy.conf

# Remove SSL certificates
sudo rm -rf /etc/apache2/ssl/postgresql.local

# Remove from /etc/hosts
sudo sed -i '/postgresql.local/d' /etc/hosts

# Reload Apache
sudo systemctl reload apache2
```

## Firewall Configuration

If you enabled remote access, configure the firewall:

### UFW (Ubuntu Firewall)

```bash
# Allow PostgreSQL
sudo ufw allow 5432/tcp

# Allow HTTP for pgAdmin (if accessing remotely)
sudo ufw allow 80/tcp

# Enable firewall
sudo ufw enable
```

### Check firewall status
```bash
sudo ufw status
```

## Useful Commands

### PostgreSQL Service Management

```bash
# Check status
sudo systemctl status postgresql

# Start service
sudo systemctl start postgresql

# Stop service
sudo systemctl stop postgresql

# Restart service
sudo systemctl restart postgresql

# Enable on boot
sudo systemctl enable postgresql
```

### pgAdmin/Apache Service Management

```bash
# Check status
sudo systemctl status apache2

# Start service
sudo systemctl start apache2

# Stop service
sudo systemctl stop apache2

# Restart service
sudo systemctl restart apache2
```

### PostgreSQL Database Operations

```bash
# List all databases
sudo -u postgres psql -c "\l"

# List all users
sudo -u postgres psql -c "\du"

# Create new database
sudo -u postgres psql -c "CREATE DATABASE newdb;"

# Create new user
sudo -u postgres psql -c "CREATE USER newuser WITH PASSWORD 'password';"

# Grant privileges
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE newdb TO newuser;"
```

### PostgreSQL Performance Monitoring

```bash
# Check current configuration
sudo -u postgres psql -c "SHOW ALL;"

# Check specific performance parameters
sudo -u postgres psql -c "SHOW shared_buffers;"
sudo -u postgres psql -c "SHOW effective_cache_size;"
sudo -u postgres psql -c "SHOW max_connections;"

# View active connections
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"

# Check database size
sudo -u postgres psql -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;"

# Check table sizes
sudo -u postgres psql -d myappdb -c "SELECT tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables WHERE schemaname = 'public' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

## Upgrading pgAdmin

The `upgrade_pgadmin.sh` script provides a safe and reversible way to upgrade pgAdmin to a newer version while preserving all configurations, SSL certificates, custom domains, and user data (server connections and preferences).

### Features

- ✅ **Configuration Preservation**: Keeps all Apache VirtualHost configurations intact
- ✅ **User Data Protection**: Preserves pgAdmin server connections and preferences
- ✅ **SSL Certificate Retention**: Maintains existing SSL certificates
- ✅ **Automatic Backup**: Creates comprehensive backup before upgrade
- ✅ **Automatic Rollback**: Reverts to previous version on failure
- ✅ **Dry Run Mode**: Test upgrade process without making changes
- ✅ **Version Flexibility**: Upgrade to latest or specific version

### Prerequisites

- Existing pgAdmin4 installation (installed via `install_postgresql_pgadmin.sh`)
- Root or sudo access
- Internet connection for downloading packages

### Quick Upgrade Guide

#### 1. Configure Upgrade Settings

Edit the `upgrade_pgadmin_config.conf` file:

```bash
nano upgrade_pgadmin_config.conf
```

**Important settings:**

```bash
# Target version ("latest" or specific version like "9.13")
TARGET_VERSION="latest"

# Preserve user data (server connections, preferences)
PRESERVE_USER_DATA="yes"

# Automatically rollback on failure
AUTO_ROLLBACK_ON_FAILURE="yes"

# Custom domain to test (if configured)
CUSTOM_DOMAIN="postgresql.local"

# Test HTTPS connectivity (if SSL is configured)
TEST_HTTPS="yes"
```

#### 2. Secure Configuration File

```bash
chmod 600 upgrade_pgadmin_config.conf
```

#### 3. Run Upgrade Script

```bash
chmod +x upgrade_pgadmin.sh
sudo ./upgrade_pgadmin.sh
```

The script will:
1. Check current pgAdmin version
2. Verify target version availability
3. Create comprehensive backup of all configurations
4. Upgrade pgAdmin package
5. Verify Apache and WSGI configurations remain intact
6. Test connectivity to ensure pgAdmin is accessible
7. Display upgrade summary with version information

### Upgrade Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `TARGET_VERSION` | Version to upgrade to ("latest" or version like "9.13") - automatically resolved to full APT version | latest |
| `PRESERVE_USER_DATA` | Keep server connections and preferences | yes |
| `AUTO_ROLLBACK_ON_FAILURE` | Auto-rollback on verification failure | yes |
| `DRY_RUN` | Test upgrade without making changes | no |
| `VERIFY_TIMEOUT` | Timeout for connectivity tests (seconds) | 10 |
| `CUSTOM_DOMAIN` | Custom domain to test (if configured) | (empty) |
| `TEST_HTTPS` | Test HTTPS connectivity | no |
| `BACKUP_APACHE_CONFIGS` | Backup Apache configurations | yes |
| `BACKUP_SSL_CERTS` | Backup SSL certificates | yes |
| `FORCE_UPGRADE` | Force upgrade even if same version | no |

### What Gets Backed Up

The upgrade script creates a timestamped backup containing:

- **pgAdmin Configuration**: `/etc/pgadmin/` - Complete pgAdmin config directory
- **User Data**: `/var/lib/pgadmin/` - Server connections, preferences, sessions
- **Apache WSGI Config**: `/etc/apache2/conf-available/pgadmin4.conf`
- **VirtualHost Configs**: All Apache site configs referencing pgadmin
- **Enabled Sites**: List of enabled Apache sites
- **SSL Certificates**: `/etc/apache2/ssl/` - All SSL certificates
- **Apache Modules**: List of enabled Apache modules
- **System State**: Version information and service status

Backup location: `/tmp/pgadmin_upgrade_backup_YYYYMMDD_HHMMSS/`

### Upgrade Scenarios

#### Upgrade to Latest Version

```bash
# In upgrade_pgadmin_config.conf
TARGET_VERSION="latest"

sudo ./upgrade_pgadmin.sh
```

#### Upgrade to Specific Version

```bash
# In upgrade_pgadmin_config.conf
TARGET_VERSION="9.13"

sudo ./upgrade_pgadmin.sh
```

**Note**: You can specify short version numbers like `"9.13"`, and the script will automatically resolve them to the full APT package version (e.g., `"9.13-1"`). The script uses `apt-cache policy` to find the matching version with the Debian revision suffix.

#### Dry Run (Test Without Changes)

```bash
# In upgrade_pgadmin_config.conf
DRY_RUN="yes"

sudo ./upgrade_pgadmin.sh
```

This performs all checks and creates backups but skips the actual package upgrade.

#### Major Version Upgrade

When upgrading across major versions (e.g., 8.x to 9.x):

1. The script will detect the major version change
2. Display a warning about potential breaking changes
3. Prompt for confirmation before proceeding
4. Recommend reviewing release notes

### Rollback Procedure

#### Automatic Rollback

If `AUTO_ROLLBACK_ON_FAILURE="yes"` (default), the script automatically rolls back on any verification failure:

- Downgrades pgAdmin package to previous version
- Restores all backed-up configurations
- Restores user data
- Restarts Apache
- Verifies rollback success

#### Manual Rollback

If automatic rollback is disabled or you need to rollback later:

```bash
# List available backups
ls -lt /tmp/pgadmin_upgrade_backup_*/

# Rollback using specific backup (replace YYYYMMDD_HHMMSS with actual timestamp)
sudo ./upgrade_pgadmin.sh --rollback /tmp/pgadmin_upgrade_backup_YYYYMMDD_HHMMSS
```

**What Manual Rollback Does:**

The script will attempt to fully restore your previous pgAdmin installation:

1. **Package Downgrade**: Automatically downgrades pgAdmin to the previous version if version information is found in the backup's `system_state.txt` file
2. **Configuration Restore**: Restores all pgAdmin configuration files
3. **User Data Restore**: Restores server connections and preferences
4. **Apache Configuration**: Restores Apache WSGI and VirtualHost configurations
5. **SSL Certificates**: Restores SSL certificates if they were backed up
6. **Service Restart**: Restarts Apache and verifies pgAdmin is accessible

**Note**: If the backup directory is missing the `system_state.txt` file or version information cannot be extracted, the script will:
- Restore all configurations and data
- Display a warning about package downgrade being skipped
- Provide the manual command to downgrade the package

**Manual Package Downgrade** (if needed):
```bash
# Check available versions
apt-cache policy pgadmin4-web

# Downgrade to specific version
sudo apt-get install -y --allow-downgrades pgadmin4-web=<version>
```

### Verification After Upgrade

The script automatically verifies:

- ✅ Apache service is running
- ✅ pgAdmin WSGI configuration exists
- ✅ pgAdmin accessible at `http://127.0.0.1/pgadmin4/`
- ✅ Custom domain accessible (if configured)
- ✅ HTTPS working (if SSL configured)
- ✅ User data directory is writable
- ✅ pgAdmin database file exists

### Post-Upgrade Checklist

After successful upgrade:

1. **Login to pgAdmin** and verify access
2. **Check server connections** - Ensure saved PostgreSQL servers are intact
3. **Test database operations** - Connect to databases and run queries
4. **Verify custom domain** - Test custom domain if configured
5. **Check SSL certificates** - Ensure HTTPS works if configured
6. **Review logs** - Check `/var/log/pgadmin_upgrade.log` for details

### Upgrade Troubleshooting

#### Upgrade Fails with "Version Not Found"

```bash
# Check available versions
apt-cache policy pgadmin4-web

# Update package lists
sudo apt-get update

# Try again
sudo ./upgrade_pgadmin.sh
```

#### Upgrade Fails with "Already Running Latest Version"

If you want to force reinstall:

```bash
# In upgrade_pgadmin_config.conf
FORCE_UPGRADE="yes"

sudo ./upgrade_pgadmin.sh
```

#### Apache Not Starting After Upgrade

```bash
# Check Apache configuration
sudo apache2ctl configtest

# Check Apache error logs
sudo tail -50 /var/log/apache2/error.log

# Manual rollback
sudo ./upgrade_pgadmin.sh --rollback /tmp/pgadmin_upgrade_backup_YYYYMMDD_HHMMSS
```

#### pgAdmin Not Accessible After Upgrade

```bash
# Verify pgAdmin WSGI config
ls -la /etc/apache2/conf-enabled/pgadmin4.conf

# Check if it's a symlink to conf-available
ls -la /etc/apache2/conf-available/pgadmin4.conf

# Re-enable if needed
sudo a2enconf pgadmin4
sudo systemctl reload apache2

# Test connectivity
curl -I http://127.0.0.1/pgadmin4/
```

#### User Data Missing After Upgrade

If server connections are missing:

```bash
# Check pgAdmin storage directory
ls -la /var/lib/pgadmin/storage/

# Verify ownership
sudo chown -R www-data:www-data /var/lib/pgadmin/

# If needed, restore from backup manually
sudo cp -r /tmp/pgadmin_upgrade_backup_YYYYMMDD_HHMMSS/var_lib_pgadmin/* /var/lib/pgadmin/
sudo chown -R www-data:www-data /var/lib/pgadmin/
sudo systemctl restart apache2
```

#### SSL Certificate Issues After Upgrade

```bash
# Verify SSL certificates exist
ls -la /etc/apache2/ssl/

# Check certificate in VirtualHost config
sudo grep -r "SSLCertificate" /etc/apache2/sites-available/

# Restore SSL certificates from backup if needed
sudo cp -r /tmp/pgadmin_upgrade_backup_YYYYMMDD_HHMMSS/apache_ssl /etc/apache2/ssl
sudo systemctl reload apache2
```

### Useful Upgrade Commands

```bash
# Check current pgAdmin version
dpkg -l | grep pgadmin4-web

# View upgrade log
sudo cat /var/log/pgadmin_upgrade.log

# List all backups
ls -lt /tmp/pgadmin_upgrade_backup_*/

# Check upgrade configuration
cat upgrade_pgadmin_config.conf

# Test pgAdmin connectivity
curl -I http://127.0.0.1/pgadmin4/

# Check Apache configuration
sudo apache2ctl -S

# View Apache modules
apache2ctl -M
```

### Cleanup Old Backups

After verifying successful upgrade, you can remove old backups:

```bash
# List backups with sizes
du -sh /tmp/pgadmin_upgrade_backup_*/

# Remove specific backup (replace YYYYMMDD_HHMMSS with actual timestamp)
sudo rm -rf /tmp/pgadmin_upgrade_backup_YYYYMMDD_HHMMSS

# Remove all backups older than 30 days
find /tmp -name "pgadmin_upgrade_backup_*" -type d -mtime +30 -exec rm -rf {} +
```

## Troubleshooting

### Installation Failed

1. Check the log file (location shown at end of script):
   ```bash
   cat /var/log/postgresql_pgadmin_install_*.log
   ```

2. The script automatically attempts rollback on failure
3. Verify prerequisites are met
4. Check for port conflicts (5432 for PostgreSQL, 80 for pgAdmin)

### Cannot Connect to PostgreSQL

1. Check if service is running:
   ```bash
   sudo systemctl status postgresql
   ```

2. Verify authentication in pg_hba.conf:
   ```bash
   sudo nano /etc/postgresql/*/main/pg_hba.conf
   ```

3. Check PostgreSQL logs:
   ```bash
   sudo tail -f /var/log/postgresql/postgresql-*-main.log
   ```

### Cannot Access pgAdmin4

1. Check if Apache is running:
   ```bash
   sudo systemctl status apache2
   ```

2. Check Apache error logs:
   ```bash
   sudo tail -f /var/log/apache2/error.log
   ```

3. Verify pgAdmin is installed:
   ```bash
   dpkg -l | grep pgadmin4
   ```

### Remote Connection Not Working

1. Verify remote access is enabled in config
2. Check firewall rules:
   ```bash
   sudo ufw status
   ```

3. Verify PostgreSQL is listening on all interfaces:
   ```bash
   sudo netstat -plnt | grep 5432
   ```
   Should show `0.0.0.0:5432`

4. Check pg_hba.conf has remote access entry:
   ```bash
   sudo cat /etc/postgresql/*/main/pg_hba.conf | grep "host.*all"
   ```

### Permission Denied Errors

1. Ensure script is run with sudo:
   ```bash
   sudo ./install_postgresql_pgadmin.sh
   ```

2. Verify config file permissions:
   ```bash
   chmod 600 install_config.conf
   ```

## Uninstallation

To completely remove PostgreSQL and pgAdmin:

```bash
# Stop services
sudo systemctl stop postgresql
sudo systemctl stop apache2

# Remove packages
sudo apt-get remove --purge postgresql postgresql-contrib pgadmin4 pgadmin4-web

# Remove data directories (WARNING: This deletes all data!)
sudo rm -rf /var/lib/postgresql
sudo rm -rf /etc/postgresql
sudo rm -rf /var/log/postgresql

# Remove pgAdmin data
sudo rm -rf /var/lib/pgadmin
sudo rm -rf /usr/pgadmin4

# Remove repository
sudo rm /etc/apt/sources.list.d/pgadmin4.list
sudo rm /usr/share/keyrings/pgadmin-archive-keyring.gpg

# Update package cache
sudo apt-get update

# Remove dependencies
sudo apt-get autoremove
```

## Security Best Practices

1. **Change Default Passwords**: Always use strong, unique passwords in `install_config.conf`
2. **Secure Config File**: Use `chmod 600` on configuration files
3. **Limit Remote Access**: Use specific IP ranges instead of `0.0.0.0/0`
4. **Enable Firewall**: Configure UFW or iptables to restrict access
5. **Regular Updates**: Keep PostgreSQL and pgAdmin updated:
   ```bash
   sudo apt-get update && sudo apt-get upgrade
   ```
6. **SSL/TLS**: Consider enabling SSL for PostgreSQL connections
7. **Backup Regularly**: Implement automated backup strategy
8. **User Privileges**: Follow principle of least privilege for database users

## Backup and Restore

### Backup Database

```bash
# Backup single database
sudo -u postgres pg_dump dbname > backup.sql

# Backup all databases
sudo -u postgres pg_dumpall > all_backup.sql

# Compressed backup
sudo -u postgres pg_dump dbname | gzip > backup.sql.gz
```

### Restore Database

```bash
# Restore database
sudo -u postgres psql dbname < backup.sql

# Restore all databases
sudo -u postgres psql < all_backup.sql

# Restore compressed backup
gunzip -c backup.sql.gz | sudo -u postgres psql dbname
```

## File Structure

```
Install_PostgreSQL_with_pgAdmin/
├── install_config.conf                 # Main installation configuration
├── install_postgresql_pgadmin.sh       # PostgreSQL & pgAdmin installation script
├── install_config_proxy.conf           # Reverse proxy configuration
├── install_apache_reverse_proxy.sh     # Apache reverse proxy setup script
├── README.md                           # This file
└── .gitignore                          # Git ignore file
```

## Version Information

- **Script Version**: 1.0.0
- **Supported OS**: Ubuntu 24.04 LTS
- **PostgreSQL**: Latest available in Ubuntu repos (typically 16+)
- **pgAdmin**: Latest from official pgAdmin repository

## Support and Contributing

For issues, questions, or contributions:
- Check troubleshooting section above
- Review log files for detailed error information
- Ensure all prerequisites are met

## License

This script is provided as-is for educational and production use.

## Changelog

### Version 1.2.0 (2026-02-19)
- **Added intelligent performance tuning with auto-detection**
- **System resource detection (RAM, CPU, disk type)**
- **Four performance profiles: low, medium, high, auto**
- **SSD/HDD disk type optimization**
- **11 PostgreSQL parameters automatically optimized**
- Custom performance configuration support
- Performance verification in installation output
- Comprehensive performance tuning documentation

### Version 1.1.0 (2026-02-19)
- Added Apache reverse proxy setup script
- Support for custom local domain (e.g., postgresql.local)
- Self-signed SSL certificate generation
- Automatic /etc/hosts configuration
- Separate configuration file for reverse proxy
- Comprehensive reverse proxy documentation

### Version 1.0.0 (2026-02-19)
- Initial release
- PostgreSQL automated installation
- pgAdmin4 Web setup
- Custom database/user creation
- Remote access configuration
- Error handling and rollback
- Comprehensive logging

---

**Note**: Always test in a non-production environment first before deploying to production servers.
