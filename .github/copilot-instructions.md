# PostgreSQL & pgAdmin Installation Script - AI Agent Guide

## Project Overview
A bash-based automation script for installing PostgreSQL database and pgAdmin4 Web on Ubuntu 24.04. The project uses a **config-driven, fail-safe architecture** with automatic rollback capabilities.

## Architecture Pattern: Config-Driven Installation with State Tracking

The script follows a strict separation of concerns:
- `install_config.conf`: User-editable configuration (passwords, DB names, feature toggles)
- `install_postgresql_pgadmin.sh`: Orchestration script with modular functions and error recovery

**State Management**: Three boolean flags track installation progress for intelligent rollback:
```bash
INSTALLATION_STARTED=false  # Triggers rollback handler
POSTGRES_INSTALLED=false    # Determines PostgreSQL cleanup
PGADMIN_INSTALLED=false     # Determines pgAdmin cleanup
```

## Critical Workflows

### Script Execution Phases
1. **Pre-flight checks** (`check_root`, `check_ubuntu_version`, `load_config`, `check_existing_installations`)
2. **Installation** (`install_postgresql`, `configure_postgresql`, `install_pgadmin`, `configure_pgadmin`)
3. **Verification** (`verify_installation`)
4. **Reporting** (`display_connection_info`)

**Error Handling**: `trap cleanup_on_error ERR` automatically invokes `rollback_installation()` on any failure after `INSTALLATION_STARTED=true`.

### Config File Pattern
All sensitive data stored in `install_config.conf` with validation in `load_config()`:
- Password length validation (min 8 chars for postgres, 6 for pgadmin)
- Boolean toggles use `"yes"/"no"` strings (NOT true/false)
- Feature flags: `CREATE_CUSTOM_USER`, `CREATE_CUSTOM_DATABASE`, `ENABLE_REMOTE_ACCESS`

## Project-Specific Conventions

### Logging System
Four-tier colored logging with dual output (console + file):
```bash
log_info()     # Blue - informational
log_success()  # Green - successful operations
log_warning()  # Yellow - non-fatal issues
log_error()    # Red - failures
```
All logs include timestamps and write to `${LOG_FILE}` (set in config).

### Configuration Backup Strategy
Before modifying PostgreSQL configs:
1. Create timestamped backup dir: `/tmp/postgresql_pgadmin_backup_YYYYMMDD_HHMMSS`
2. Copy `pg_hba.conf` and `postgresql.conf` to backup dir
3. Modify configs in-place
4. On rollback, restore from backup dir

### PostgreSQL Configuration Discovery
Uses dynamic discovery instead of hardcoded paths:
```bash
pg_config_dir=$(sudo -u postgres psql -t -c "SHOW config_file;" | xargs dirname)
```

## Key Integration Points

### Remote Access Configuration
When `ENABLE_REMOTE_ACCESS="yes"`:
1. Modifies `postgresql.conf`: `listen_addresses = '*'`
2. Appends to `pg_hba.conf`: `host all all ${ALLOWED_IP_RANGE} md5`
3. Requires PostgreSQL service restart

### pgAdmin4 Setup
Non-interactive setup using input redirection:
```bash
cat > /tmp/pgadmin_setup_input.txt <<EOF
${PGADMIN_EMAIL}
${PGADMIN_PASSWORD}
${PGADMIN_PASSWORD}
y
EOF
/usr/pgadmin4/bin/setup-web.sh < /tmp/pgadmin_setup_input.txt
```

## Security Conventions

1. **Config file must be secured**: `chmod 600 install_config.conf` (documented in README)
2. **Secrets never logged**: Passwords never appear in log output
3. **Default values are intentionally weak**: Forces user to change before use
4. **Remote access defaults to disabled**: Must be explicitly enabled in config

## Testing & Debugging

### Script Testing
Always test with: `bash -n install_postgresql_pgadmin.sh` (syntax check)

### Rollback Testing
Set `INSTALLATION_STARTED=true` early to test cleanup logic without full installation.

### Log Analysis
Check timestamped log files in `/var/log/postgresql_pgadmin_install_*.log` for detailed execution traces.

## Common Modifications

### Adding New Configuration Options
1. Add variable to `install_config.conf` with comment and default
2. Add validation in `load_config()` if required
3. Use in appropriate function (e.g., `configure_postgresql()`)

### Adding New Installation Steps
1. Create new function following naming pattern: `verb_component()`
2. Call from `main()` in logical sequence
3. Add corresponding state flag if needs rollback tracking
4. Add cleanup logic to `rollback_installation()`

### Extending to Other Ubuntu Versions
Modify `check_ubuntu_version()` - currently warns on non-24.04 but continues execution.

## File Dependencies

- `install_config.conf`: Required before execution (script validates presence)
- `README.md`: User-facing documentation (keep synchronized with script features)
- `.gitignore`: Must exclude `install_config.conf` to prevent credential leaks
