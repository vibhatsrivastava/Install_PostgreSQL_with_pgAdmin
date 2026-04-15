# PostgreSQL and pgAdmin Command Reference

Quick reference for common PostgreSQL, pgAdmin, and system management commands.

## Service Management

### PostgreSQL Service

```bash
# Check status
sudo systemctl status postgresql

# Start service
sudo systemctl start postgresql

# Stop service
sudo systemctl stop postgresql

# Restart service
sudo systemctl restart postgresql

# Reload configuration without restart
sudo systemctl reload postgresql

# Enable on boot
sudo systemctl enable postgresql

# Disable on boot
sudo systemctl disable postgresql

# View logs
sudo journalctl -u postgresql -f
```

### pgAdmin / Apache Service

```bash
# Check status
sudo systemctl status apache2

# Start service
sudo systemctl start apache2

# Stop service
sudo systemctl stop apache2

# Restart service
sudo systemctl restart apache2

# Reload configuration
sudo systemctl reload apache2

# Enable on boot
sudo systemctl enable apache2

# View logs
sudo tail -f /var/log/apache2/error.log
```

## PostgreSQL Connection

### Command Line Access

```bash
# Connect as postgres superuser
sudo -u postgres psql

# Connect to specific database
sudo -u postgres psql -d myappdb

# Connect as custom user
psql -U dbuser -d myappdb -h localhost

# Connect with connection string
psql "postgresql://dbuser:password@localhost:5432/myappdb"

# Execute single command
sudo -u postgres psql -c "SELECT version();"

# Execute SQL file
sudo -u postgres psql -d myappdb -f /path/to/script.sql
```

### psql Meta-Commands

```sql
-- List databases
\l

-- Connect to database
\c myappdb

-- List tables
\dt

-- Describe table
\d tablename

-- List users/roles
\du

-- List schemas
\dn

-- Show current database and user
\conninfo

-- Execute system command
\! ls -la

-- Import SQL file
\i /path/to/file.sql

-- Show query timing
\timing

-- Quit psql
\q
```

## Database Operations

### Database Management

```bash
# Create database
sudo -u postgres psql -c "CREATE DATABASE newdb;"

# Drop database
sudo -u postgres psql -c "DROP DATABASE olddb;"

# List all databases
sudo -u postgres psql -c "\l"

# Database size
sudo -u postgres psql -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database;"

# Backup database
sudo -u postgres pg_dump myappdb > backup.sql

# Restore database
sudo -u postgres psql myappdb < backup.sql

# Backup all databases
sudo -u postgres pg_dumpall > all_databases.sql
```

### User Management

```bash
# Create user
sudo -u postgres psql -c "CREATE USER newuser WITH PASSWORD 'password';"

# Create user with privileges
sudo -u postgres psql -c "CREATE USER admin WITH SUPERUSER PASSWORD 'password';"

# Drop user
sudo -u postgres psql -c "DROP USER olduser;"

# List users
sudo -u postgres psql -c "\du"

# Change user password
sudo -u postgres psql -c "ALTER USER dbuser WITH PASSWORD 'newpassword';"

# Grant privileges
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE myappdb TO dbuser;"

# Revoke privileges
sudo -u postgres psql -c "REVOKE ALL PRIVILEGES ON DATABASE myappdb FROM dbuser;"
```

### Table Operations

```sql
-- Create table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Drop table
DROP TABLE users;

-- List tables
\dt

-- Describe table structure
\d users

-- Table size
SELECT pg_size_pretty(pg_total_relation_size('users'));

-- Copy table
CREATE TABLE users_backup AS SELECT * FROM users;

-- Truncate table (delete all rows)
TRUNCATE TABLE users;
```

## Performance Monitoring

### Active Connections

```bash
# View all active connections
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"

# View active queries
sudo -u postgres psql -c "SELECT pid, usename, state, query FROM pg_stat_activity WHERE state != 'idle';"

# Kill a connection
sudo -u postgres psql -c "SELECT pg_terminate_backend(12345);"  # Replace 12345 with PID

# Count connections per database
sudo -u postgres psql -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"
```

### Database Statistics

```bash
# Database sizes
sudo -u postgres psql -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database ORDER BY pg_database_size(datname) DESC;"

# Table sizes
sudo -u postgres psql -d myappdb -c "SELECT tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables WHERE schemaname = 'public' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"

# Index usage
sudo -u postgres psql -d myappdb -c "SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, pg_size_pretty(pg_relation_size(indexrelid)) AS size FROM pg_stat_user_indexes ORDER BY idx_scan DESC;"

# Cache hit ratio
sudo -u postgres psql -c "SELECT sum(heap_blks_read) as heap_read, sum(heap_blks_hit) as heap_hit, sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio FROM pg_statio_user_tables;"
```

### Configuration

```bash
# View current configuration
sudo -u postgres psql -c "SHOW ALL;"

# View specific parameter
sudo -u postgres psql -c "SHOW shared_buffers;"

# Change parameter (session level)
sudo -u postgres psql -c "SET work_mem = '16MB';"

# Change parameter (permanent - requires reload)
sudo -u postgres psql -c "ALTER SYSTEM SET work_mem = '16MB';"
sudo systemctl reload postgresql

# View configuration file location
sudo -u postgres psql -c "SHOW config_file;"

# Reload configuration
sudo -u postgres psql -c "SELECT pg_reload_conf();"
```

## Maintenance

### VACUUM and ANALYZE

```bash
# Vacuum database (reclaim space)
sudo -u postgres psql -d myappdb -c "VACUUM;"

# Vacuum specific table
sudo -u postgres psql -d myappdb -c "VACUUM users;"

# Vacuum full (more thorough, locks table)
sudo -u postgres psql -d myappdb -c "VACUUM FULL;"

# Analyze database (update statistics)
sudo -u postgres psql -d myappdb -c "ANALYZE;"

# Vacuum and analyze together
sudo -u postgres psql -d myappdb -c "VACUUM ANALYZE;"

# Auto-vacuum status
sudo -u postgres psql -c "SELECT * FROM pg_stat_all_tables WHERE schemaname = 'public';"
```

### Reindexing

```bash
# Reindex database
sudo -u postgres psql -d myappdb -c "REINDEX DATABASE myappdb;"

# Reindex table
sudo -u postgres psql -d myappdb -c "REINDEX TABLE users;"

# Reindex specific index
sudo -u postgres psql -d myappdb -c "REINDEX INDEX users_email_idx;"
```

### Logs

```bash
# PostgreSQL log location
sudo tail -f /var/log/postgresql/postgresql-*-main.log

# Show last 50 log entries
sudo tail -50 /var/log/postgresql/postgresql-*-main.log

# Search logs for errors
sudo grep "ERROR" /var/log/postgresql/postgresql-*-main.log

# Search logs for specific term
sudo grep "connection" /var/log/postgresql/postgresql-*-main.log
```

## Firewall Configuration

### UFW (Ubuntu Firewall)

```bash
# Allow PostgreSQL
sudo ufw allow 5432/tcp

# Allow from specific IP
sudo ufw allow from 192.168.1.0/24 to any port 5432

# Allow HTTP (pgAdmin)
sudo ufw allow 80/tcp

# Allow HTTPS
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status

# Disable rule
sudo ufw delete allow 5432/tcp
```

## Backup and Restore

### Full Database Backup

```bash
# Backup single database
sudo -u postgres pg_dump myappdb > myappdb_backup_$(date +%Y%m%d).sql

# Backup with compression
sudo -u postgres pg_dump myappdb | gzip > myappdb_backup_$(date +%Y%m%d).sql.gz

# Backup all databases
sudo -u postgres pg_dumpall > all_databases_backup_$(date +%Y%m%d).sql

# Backup specific schema
sudo -u postgres pg_dump -n public myappdb > myappdb_public_schema.sql

# Backup specific table
sudo -u postgres pg_dump -t users myappdb > users_table.sql
```

### Restore

```bash
# Restore database
sudo -u postgres psql myappdb < myappdb_backup.sql

# Restore compressed backup
gunzip -c myappdb_backup.sql.gz | sudo -u postgres psql myappdb

# Restore all databases
sudo -u postgres psql < all_databases_backup.sql

# Create new database and restore
sudo -u postgres psql -c "CREATE DATABASE myappdb;"
sudo -u postgres psql myappdb < myappdb_backup.sql
```

## pgAdmin Management

### Access pgAdmin

```bash
# Local access
http://localhost/pgadmin4

# With reverse proxy
https://postgresql.local/

# Check if pgAdmin is running
curl -I http://localhost/pgadmin4/
```

### pgAdmin Configuration

```bash
# pgAdmin config directory
/var/lib/pgadmin/

# pgAdmin logs
/var/log/pgadmin/

# Reset pgAdmin setup
sudo /usr/pgadmin4/bin/setup-web.sh
```

## Troubleshooting Commands

### Connection Issues

```bash
# Test PostgreSQL is listening
sudo netstat -plnt | grep postgres

# Test local connection
psql -U postgres -h localhost -c "SELECT 1;"

# Check PostgreSQL logs
sudo tail -50 /var/log/postgresql/postgresql-*-main.log

# Check pg_hba.conf (connection rules)
sudo cat /etc/postgresql/*/main/pg_hba.conf
```

### Performance Issues

```bash
# Find slow queries
sudo -u postgres psql -c "SELECT pid, now() - query_start as duration, query FROM pg_stat_activity WHERE state != 'idle' ORDER BY duration DESC;"

# Check locks
sudo -u postgres psql -c "SELECT * FROM pg_locks;"

# Check bloat
sudo -u postgres psql -d myappdb -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size, n_dead_tup FROM pg_stat_user_tables ORDER BY n_dead_tup DESC;"
```

---

**Related Documentation:**
- [Configuration Reference](CONFIGURATION.md)
- [Performance Tuning Guide](PERFORMANCE_TUNING.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Back to Main README](../README.md)
