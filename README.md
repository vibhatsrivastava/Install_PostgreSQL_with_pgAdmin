# PostgreSQL and pgAdmin4 Installation for Ubuntu 24.04

Automated installation scripts for PostgreSQL database server and pgAdmin4 web interface on Ubuntu 24.04 LTS.

## Features

- ✅ **Core Installation**: PostgreSQL and pgAdmin4 Web interface
- ✅ **AI/ML Ready**: pgVector extension for vector similarity search
- ✅ **CDC Replication**: Real-time data sync with vector embeddings via Ollama
- ✅ **Performance Tuning**: Intelligent auto-optimization based on system resources
- ✅ **Security**: Optional remote access, SSL certificates, reverse proxy
- ✅ **Monitoring**: Prometheus metrics for replication tracking
- ✅ **Reliability**: Automatic rollback on errors, comprehensive logging

## Prerequisites

- **OS**: Ubuntu 24.04 LTS
- **Access**: Root or sudo privileges
- **Network**: Internet connection for package downloads
- **Storage**: Minimum 500MB free space

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd Install_PostgreSQL_with_pgAdmin
```

### 2. Configure Installation

Edit the configuration file in the `configs/` directory:

```bash
nano configs/install_config.conf
```

**Key settings to customize:**

```bash
# PostgreSQL superuser password (min 8 characters)
POSTGRES_PASSWORD="ChangeMe123!"

# pgAdmin web interface credentials
PGADMIN_EMAIL="admin@example.com"
PGADMIN_PASSWORD="Admin123!"

# Custom database and user
CUSTOM_USERNAME="dbuser"
CUSTOM_USER_PASSWORD="SecurePass456!"
CUSTOM_DATABASE_NAME="myappdb"

# Optional features
ENABLE_REMOTE_ACCESS="no"              # Allow remote connections
APPLY_PERFORMANCE_TUNING="yes"         # Auto-optimize PostgreSQL
```

### 3. Secure and Run

```bash
# Secure the configuration file
chmod 600 configs/install_config.conf

# Run installation
chmod +x install_postgresql_pgadmin.sh
sudo ./install_postgresql_pgadmin.sh
```

The installer will validate your system, install packages, configure services, and display connection details.

## Accessing Services

### PostgreSQL Database

**Local connection:**
```bash
# As postgres superuser
sudo -u postgres psql

# As custom user
psql -U dbuser -d myappdb -h localhost
```

**Connection string:**
```
postgresql://dbuser:SecurePass456!@localhost:5432/myappdb
```

### pgAdmin4 Web Interface

**Local access:**
```
http://localhost/pgadmin4
```

**Login credentials:** Use the email and password you configured in `PGADMIN_EMAIL` and `PGADMIN_PASSWORD`.

## Advanced Features

### 📊 Performance Tuning

Automatically optimizes PostgreSQL based on your system resources (RAM, CPU cores, disk type).

```bash
# In configs/install_config.conf
APPLY_PERFORMANCE_TUNING="yes"
PERFORMANCE_PROFILE="auto"  # Options: auto, low, medium, high, custom
```

**[📖 Full Performance Tuning Guide →](docs/PERFORMANCE_TUNING.md)**

### 🔄 CDC Replication with Vector Embeddings

Real-time data replication with automatic vector embedding generation using Ollama AI models. Perfect for building semantic search applications.

**Prerequisites:** PostgreSQL installed, pgVector extension, Ollama running

```bash
# Configure CDC replication
nano configs/install_cdc_config.conf

# Run CDC installer
sudo ./install_cdc_replication.sh
```

**[📖 Complete CDC Setup Guide →](docs/CDC_REPLICATION.md)**

### 🌐 Apache Reverse Proxy (Optional)

Access pgAdmin through a custom domain with SSL support (e.g., `https://postgresql.local`).

**Prerequisites:** PostgreSQL and pgAdmin already installed

```bash
# Configure reverse proxy
nano configs/install_config_proxy.conf

# Run proxy installer
sudo ./install_apache_reverse_proxy.sh
```

**[📖 Reverse Proxy Configuration →](docs/APACHE_PROXY.md)**

### 🔧 pgVector Extension

Enable vector similarity search for AI/ML applications.

```bash
sudo ./install_pgvector.sh
```

**[📖 pgVector Documentation →](docs/PGVECTOR.md)**

### ⬆️ Upgrade pgAdmin

Safely upgrade pgAdmin with automatic backup and rollback capability.

```bash
# Configure upgrade
nano configs/upgrade_pgadmin_config.conf

# Run upgrade
sudo ./upgrade_pgadmin.sh
```

**[📖 Upgrade Guide →](docs/PGADMIN_UPGRADE.md)**

## Documentation

- **[Configuration Reference](docs/CONFIGURATION.md)** - Detailed configuration options
- **[Performance Tuning](docs/PERFORMANCE_TUNING.md)** - Optimization strategies
- **[CDC Replication](docs/CDC_REPLICATION.md)** - Real-time data sync with embeddings
- **[Apache Reverse Proxy](docs/APACHE_PROXY.md)** - SSL and custom domains
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Management Commands](docs/COMMANDS.md)** - Useful PostgreSQL and pgAdmin commands

## Service Management

### PostgreSQL

```bash
sudo systemctl status postgresql    # Check status
sudo systemctl restart postgresql   # Restart service
```

### pgAdmin / Apache

```bash
sudo systemctl status apache2       # Check status
sudo systemctl restart apache2      # Restart service
```

## Security Best Practices

1. **Change default passwords** before running installation
2. **Secure configuration files**: `chmod 600 configs/*.conf`
3. **Enable firewall** if using remote access:
   ```bash
   sudo ufw allow 5432/tcp  # PostgreSQL
   sudo ufw allow 80/tcp    # HTTP (pgAdmin)
   sudo ufw enable
   ```
4. **Restrict remote access** using `ALLOWED_IP_RANGE` in configuration
5. **Use SSL certificates** for production environments

## Cleanup

To remove stuck or failed installations:

```bash
sudo ./cleanup_stuck_installation.sh
```

## Support and Contribution

- **Issues**: Report bugs or request features via GitHub issues
- **Documentation**: Help improve docs by submitting pull requests
- **Testing**: Test on different Ubuntu configurations and share feedback

## License

This project is open-source. Check the repository for license details.

---

**Quick Links:**
[Configuration](docs/CONFIGURATION.md) | [Performance](docs/PERFORMANCE_TUNING.md) | [CDC Setup](docs/CDC_REPLICATION.md) | [Troubleshooting](docs/TROUBLESHOOTING.md)
