# pgAdmin Upgrade Guide

Safely upgrade pgAdmin to a newer version while preserving all configurations, SSL certificates, and user data.

## Overview

The `upgrade_pgadmin.sh` script provides:

- ✅ **Configuration Preservation**: Keeps all Apache VirtualHost configurations intact
- ✅ **User Data Protection**: Preserves pgAdmin server connections and preferences
- ✅ **SSL Certificate Retention**: Maintains existing SSL certificates
- ✅ **Automatic Backup**: Creates comprehensive backup before upgrade
- ✅ **Automatic Rollback**: Reverts to previous version on failure
- ✅ **Dry Run Mode**: Test upgrade process without making changes
- ✅ **Version Flexibility**: Upgrade to latest or specific version

## Prerequisites

- Existing pgAdmin4 installation (installed via `install_postgresql_pgadmin.sh`)
- Root or sudo access
- Internet connection for downloading packages

## Quick Start

### 1. Configure Upgrade Settings

Edit the configuration file:

```bash
nano configs/upgrade_pgadmin_config.conf
```

**Important settings:**

```bash
# Target version ("latest" or specific version like "9.13")
TARGET_VERSION="latest"

# Dry run mode (test without making changes)
DRY_RUN="no"

# Backup directory
BACKUP_DIR="/tmp/pgadmin_backup_$(date +%Y%m%d_%H%M%S)"

# Keep backup after successful upgrade
KEEP_BACKUP="yes"
```

### 2. Secure Configuration File

```bash
chmod 600 configs/upgrade_pgadmin_config.conf
```

### 3. Run Upgrade Script

```bash
chmod +x upgrade_pgadmin.sh
sudo ./upgrade_pgadmin.sh
```

The script will:
1. Check current pgAdmin version
2. Create backup of configuration and user data
3. Download and install target version
4. Preserve Apache configurations and SSL certificates
5. Verify upgrade success
6. Display version information

## Configuration Options

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `TARGET_VERSION` | Target pgAdmin version | latest, X.Y | latest |
| `DRY_RUN` | Test without making changes | yes, no | no |
| `BACKUP_DIR` | Backup directory path | Directory path | /tmp/pgadmin_backup_* |
| `KEEP_BACKUP` | Keep backup after success | yes, no | yes |

## Dry Run Mode

Test the upgrade process without making any changes:

```bash
# In configs/upgrade_pgadmin_config.conf
DRY_RUN="yes"

# Run upgrade
sudo ./upgrade_pgadmin.sh
```

Dry run will:
- Show what would be upgraded
- Check system compatibility
- Verify backup locations
- Display planned actions
- **NOT** modify any files

## Upgrade Specific Version

```bash
# In configs/upgrade_pgadmin_config.conf
TARGET_VERSION="9.13"  # Specific version

# Or for latest
TARGET_VERSION="latest"
```

## What Gets Preserved

### Configuration Files
- Apache VirtualHost configurations
- Custom domain settings (e.g., postgresql.local)
- SSL certificates and keys
- Proxy configurations

### User Data
- Server connections
- User preferences
- Saved queries
- Browser favorites

### System Integrations
- Apache module configurations
- Reverse proxy settings
- Firewall rules

## Automatic Rollback

If upgrade fails, the script automatically:

1. Stops failed installation
2. Removes new pgAdmin packages
3. Restores previous version from backup
4. Verifies rollback success
5. Displays error information

## Manual Rollback

If you need to manually rollback:

```bash
# Stop Apache
sudo systemctl stop apache2

# Reinstall previous version
sudo apt install pgadmin4 pgadmin4-web=<previous-version>

# Restore backup
sudo cp -r /tmp/pgadmin_backup_*/pgadmin/* /var/lib/pgadmin/
sudo cp -r /tmp/pgadmin_backup_*/apache/* /etc/apache2/

# Restart Apache
sudo systemctl start apache2
```

## Verifying Upgrade

### Check Version

```bash
# Check installed version
dpkg -l | grep pgadmin4

# Check in web interface
# Login to pgAdmin → Help → About
```

### Test Functionality

1. Access pgAdmin web interface
2. Check server connections still work
3. Verify custom domains (if configured)
4. Test SSL certificates (if configured)
5. Check saved queries and preferences

## Troubleshooting

### Upgrade Fails with Package Errors

**Symptom:** apt package manager errors

```bash
# Fix broken packages
sudo apt --fix-broken install

# Clean package cache
sudo apt clean
sudo apt update

# Retry upgrade
sudo ./upgrade_pgadmin.sh
```

### pgAdmin Won't Start After Upgrade

**Symptom:** Cannot access web interface

```bash
# Check Apache status
sudo systemctl status apache2

# Check Apache error logs
sudo tail -50 /var/log/apache2/error.log

# Restart Apache
sudo systemctl restart apache2

# Re-run pgAdmin setup
sudo /usr/pgadmin4/bin/setup-web.sh
```

### Server Connections Lost

**Symptom:** Previously configured servers not showing

**Solution:**
Restore user data from backup:

```bash
# Find backup directory
ls -la /tmp/pgadmin_backup_*

# Restore pgAdmin user data
sudo cp -r /tmp/pgadmin_backup_*/pgadmin/* /var/lib/pgadmin/

# Restart Apache
sudo systemctl restart apache2
```

### SSL Certificates Missing

**Symptom:** HTTPS not working after upgrade

**Solution:**
Restore SSL certificates:

```bash
# Restore Apache SSL configurations
sudo cp -r /tmp/pgadmin_backup_*/apache/ssl /etc/apache2/

# Restart Apache
sudo systemctl restart apache2
```

## Cleanup

### Remove Old Backups

```bash
# List backups
ls -la /tmp/pgadmin_backup_*

# Remove specific backup
sudo rm -rf /tmp/pgadmin_backup_20240415_120000

# Remove all old backups
sudo rm -rf /tmp/pgadmin_backup_*
```

### Clean Package Cache

```bash
# Remove downloaded packages
sudo apt clean

# Remove unused dependencies
sudo apt autoremove
```

## Best Practices

1. **Always backup first**: Don't skip the backup step
2. **Test in development**: Try upgrade on test system first
3. **Use dry run**: Test the upgrade without making changes
4. **Check release notes**: Review pgAdmin changelog before upgrading
5. **Schedule during low usage**: Upgrade during maintenance window
6. **Keep backups**: Don't delete backups immediately after upgrade
7. **Document the upgrade**: Note versions and any issues encountered

## Downgrading pgAdmin

To downgrade to a previous version:

```bash
# Stop Apache
sudo systemctl stop apache2

# Remove current version
sudo apt remove --purge pgadmin4 pgadmin4-web

# Install specific older version
sudo apt install pgadmin4=<version> pgadmin4-web=<version>

# Restore configuration from backup
sudo cp -r /tmp/pgadmin_backup_*/pgadmin/* /var/lib/pgadmin/
sudo cp -r /tmp/pgadmin_backup_*/apache/* /etc/apache2/

# Start Apache
sudo systemctl start apache2
```

## Related Commands

```bash
# Check current pgAdmin version
dpkg -l | grep pgadmin4

# List available versions
apt-cache madison pgadmin4

# View pgAdmin logs
sudo tail -f /var/log/pgadmin/pgadmin4.log

# Check Apache configuration
sudo apache2ctl -t

# Restart services
sudo systemctl restart apache2
```

---

**Related Documentation:**
- [Configuration Reference](CONFIGURATION.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Apache Proxy Setup](APACHE_PROXY.md)
- [Back to Main README](../README.md)
