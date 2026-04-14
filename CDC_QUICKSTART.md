# CDC Replication & Vector Embedding - Quick Start Guide

## Overview

The CDC (Change Data Capture) installation script sets up real-time data replication between PostgreSQL databases with automatic vector embedding generation using Ollama.

## What Was Created

### 1. Configuration File
- **Location**: `configs/install_cdc_config.conf`
- **Purpose**: Contains all settings for CDC setup
- **Security**: Must be secured with `chmod 600 configs/install_cdc_config.conf`

### 2. Installation Script
- **Location**: `install_cdc_replication.sh`
- **Size**: ~43 KB
- **Features**: Full automation with rollback capability

### 3. Generated Components (during installation)
- **DDL Replication Worker**: `/usr/local/bin/replicate_ddl_changes.py`
- **Systemd Services**: 
  - `ddl-replication-worker.service`
  - `postgres_exporter.service`
- **Database Objects**: Publications, subscriptions, triggers, functions

## Prerequisites

### Required Before Installation

1. **PostgreSQL Installed and Running**
   ```bash
   systemctl status postgresql
   ```

2. **Source Database and Table Exist**
   - Database: `ansible_execution_results` (or your configured name)
   - Table: `failed_jobs` (must have PRIMARY KEY)
   - Column for vectorization: `error_message` (text column)

3. **Ollama Running with Model**
   
   Ollama can run either locally on the PostgreSQL server or on a remote server.
   
   **For Local Ollama (default):**
   ```bash
   # Check Ollama service
   systemctl status ollama
   # OR if running manually
   ps aux | grep ollama
   
   # Pull the embedding model
   ollama pull nomic-embed-text
   
   # Verify model is available
   ollama list | grep nomic-embed-text
   
   # Test API endpoint
   curl http://localhost:11434/api/tags
   ```
   
   **For Remote Ollama (e.g., http://10.0.0.15:11434):**
   ```bash
   # Test connectivity to remote Ollama
   curl http://10.0.0.15:11434/api/tags
   
   # Verify the embedding model is available on remote server
   curl http://10.0.0.15:11434/api/tags | grep -i nomic-embed-text
   
   # Test embedding generation
   curl http://10.0.0.15:11434/api/embeddings -d '{
     "model": "nomic-embed-text",
     "prompt": "test"
   }'
   ```
   
   **Important:** If using remote Ollama, ensure the PostgreSQL server can reach the Ollama server on port 11434.

4. **pgVector Extension Available**
   - Should be installed if you ran `install_pgvector.sh`
   - Verify: `apt list --installed | grep pgvector`

## Installation Steps

### Step 1: Configure Settings

Edit the configuration file with your specific settings:

```bash
nano configs/install_cdc_config.conf
```

**Critical Settings to Update:**
- `POSTGRES_PASSWORD` - Your PostgreSQL postgres user password
- `SOURCE_DATABASE` - Name of your source database (default: ansible_execution_results)
- `SOURCE_TABLE` - Name of table to replicate (default: failed_jobs)
- `TEXT_COLUMN_TO_VECTORIZE` - Column name containing text for embeddings (default: error_message)
- `OLLAMA_API_URL` - Ollama API endpoint
  - Local: `http://localhost:11434` (default)
  - Remote: `http://<ollama-server-ip>:11434` (e.g., `http://10.0.0.15:11434`)

**Optional Settings:**
- Feature toggles (ENABLE_DDL_REPLICATION, ENABLE_EMBEDDING_GENERATION, etc.)
- Performance tuning (batch sizes, poll intervals)
- Monitoring configuration

### Step 2: Secure the Configuration File

```bash
chmod 600 configs/install_cdc_config.conf
```

This prevents unauthorized access to your passwords and API keys.

### Step 3: Verify Prerequisites

Check that all prerequisites are met:

```bash
# PostgreSQL running
sudo systemctl status postgresql

# Source database exists
sudo -u postgres psql -l | grep ansible_execution_results

# Source table exists with primary key
sudo -u postgres psql -d ansible_execution_results -c "\d failed_jobs"

# Ollama is accessible (adjust URL if using remote Ollama)
# For local Ollama:
curl http://localhost:11434/api/tags
# For remote Ollama (e.g., http://10.0.0.15:11434):
# curl http://10.0.0.15:11434/api/tags

# Embedding model is available (adjust URL if using remote Ollama)
# For local Ollama:
ollama list | grep nomic-embed-text
# For remote Ollama:
# curl http://10.0.0.15:11434/api/tags | grep -i nomic-embed-text
```

### Step 4: Run the Installation

```bash
sudo ./install_cdc_replication.sh
```

The script will:
1. ✅ Validate all prerequisites
2. ✅ Backup PostgreSQL configuration
3. ✅ Enable logical replication (requires PostgreSQL restart)
4. ✅ Create target database with pgvector
5. ✅ Set up publication/subscription
6. ✅ Wait for initial data sync
7. ✅ Configure DDL replication (if enabled)
8. ✅ Set up automatic embedding generation (if enabled)
9. ✅ Install Prometheus monitoring (if enabled)
10. ✅ Run verification tests

**Installation Time**: 5-15 minutes (depending on data volume and features enabled)

## Post-Installation Verification

### Check Replication Status

```bash
# Check subscription status
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "SELECT * FROM pg_stat_subscription;"

# Check replication lag
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "SELECT now() - last_msg_send_time as lag FROM pg_stat_subscription WHERE subname = 'ansible_failed_jobs_sub';"

# Verify row counts match
echo "Source count:"
sudo -u postgres psql -d ansible_execution_results -t -c "SELECT COUNT(*) FROM failed_jobs;"
echo "Target count:"
sudo -u postgres psql -d ansible_failed_jobs_vectordb -t -c "SELECT COUNT(*) FROM failed_jobs;"
```

### Check DDL Replication (if enabled)

```bash
# Check DDL worker service
sudo systemctl status ddl-replication-worker

# View DDL worker logs
tail -f /var/log/ddl_replication.log

# Test DDL propagation
sudo -u postgres psql -d ansible_execution_results -c "ALTER TABLE failed_jobs ADD COLUMN test_ddl_col TEXT;"
# Wait 30-60 seconds, then check target database
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "\d failed_jobs"
```

### Check Embedding Generation (if enabled)

```bash
# Check if embeddings exist
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "SELECT COUNT(*) FROM failed_jobs WHERE error_message_embedding IS NOT NULL;"

# Test embedding function
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "SELECT generate_embedding('test error message');"

# Test semantic search
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT error_message, error_message_embedding <-> generate_embedding('connection timeout error') as distance 
FROM failed_jobs 
WHERE error_message_embedding IS NOT NULL 
ORDER BY distance 
LIMIT 5;"
```

### Check Monitoring (if enabled)

```bash
# Check postgres_exporter service
sudo systemctl status postgres_exporter

# View metrics endpoint
curl http://localhost:9187/metrics | grep pg_replication

# Check specific replication lag metric
curl -s http://localhost:9187/metrics | grep pg_replication_lag
```

## Testing Real-Time Replication

### Test INSERT Replication

```bash
# Insert a new row in source database
sudo -u postgres psql -d ansible_execution_results -c "
INSERT INTO failed_jobs (error_message, created_at) 
VALUES ('Test replication error', NOW());"

# Wait 1-2 seconds, then check target database
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT error_message, created_at, 
       CASE WHEN error_message_embedding IS NOT NULL THEN 'YES' ELSE 'NO' END as has_embedding
FROM failed_jobs 
ORDER BY created_at DESC 
LIMIT 1;"
```

Expected result:
- Row should appear in target database within 1 second
- `has_embedding` should be 'YES' if embedding generation is enabled
- Embedding should be generated within 2-3 seconds

### Test UPDATE Replication

```bash
# Update a row in source database
sudo -u postgres psql -d ansible_execution_results -c "
UPDATE failed_jobs 
SET error_message = 'Updated error message' 
WHERE id = 1;"

# Check target database
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT id, error_message FROM failed_jobs WHERE id = 1;"
```

### Test DELETE Replication

```bash
# Delete a test row from source database
sudo -u postgres psql -d ansible_execution_results -c "
DELETE FROM failed_jobs WHERE error_message = 'Test replication error';"

# Verify deletion in target database
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT COUNT(*) FROM failed_jobs WHERE error_message = 'Test replication error';"
```

## Monitoring & Maintenance

### Daily Monitoring

```bash
# Check replication lag
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT subname, 
       last_msg_send_time, 
       now() - last_msg_send_time as lag 
FROM pg_stat_subscription;"

# Check for replication errors
sudo journalctl -u postgresql -n 50 | grep -i "logical\|replication\|subscription"

# Check DDL worker health
sudo systemctl status ddl-replication-worker
```

### Weekly Maintenance

```bash
# Check disk space (WAL files can grow)
df -h /var/lib/postgresql

# Check replication slot lag
sudo -u postgres psql -c "
SELECT slot_name, 
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) as lag_size
FROM pg_replication_slots;"

# Verify embedding generation is keeping up
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT 
  COUNT(*) as total_rows,
  COUNT(error_message_embedding) as rows_with_embeddings,
  ROUND(100.0 * COUNT(error_message_embedding) / COUNT(*), 2) as percentage_complete
FROM failed_jobs;"
```

### Log Files

- **Main installation log**: `/var/log/cdc_replication_install_YYYYMMDD_HHMMSS.log`
- **DDL worker log**: `/var/log/ddl_replication.log`
- **PostgreSQL logs**: `/var/log/postgresql/postgresql-{version}-main.log`

## Troubleshooting

### Replication Not Working

```bash
# Check subscription state
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT subname, pid, received_lsn, latest_end_lsn, 
       last_msg_send_time, last_msg_receipt_time
FROM pg_stat_subscription;"

# Restart subscription if needed
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
ALTER SUBSCRIPTION ansible_failed_jobs_sub DISABLE;
ALTER SUBSCRIPTION ansible_failed_jobs_sub ENABLE;"
```

### Embeddings Not Generating

```bash
# Check Ollama service connectivity (adjust URL based on your config)
# For local Ollama:
curl http://localhost:11434/api/tags
# For remote Ollama (replace with your OLLAMA_API_URL):
# curl http://10.0.0.15:11434/api/tags

# Test embedding function manually
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT generate_embedding('test');"

# Check trigger exists
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
\d failed_jobs" | grep -i trigger

# View PostgreSQL logs for plpython errors
sudo tail -f /var/log/postgresql/postgresql-*-main.log | grep -i "plpython\|embedding"
```

### DDL Replication Not Working

```bash
# Check DDL worker service
sudo systemctl status ddl-replication-worker
sudo journalctl -u ddl-replication-worker -n 50

# Restart DDL worker
sudo systemctl restart ddl-replication-worker

# Check DDL log for errors
tail -f /var/log/ddl_replication.log

# Manually check pending DDL changes
sudo -u postgres psql -d ansible_execution_results -c "
SELECT * FROM ddl_replication_log WHERE processed = FALSE;"
```

### High Replication Lag

```bash
# Check WAL sender processes
ps aux | grep "wal sender"

# Check logical replication workers
ps aux | grep "logical replication worker"

# Increase workers if needed (in postgresql.conf)
# max_logical_replication_workers = 8

# Check system resources
top
df -h
```

## Uninstalling / Rollback

If you need to remove the CDC setup:

```bash
# Stop services
sudo systemctl stop ddl-replication-worker postgres_exporter

# Drop subscription and publication
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "DROP SUBSCRIPTION IF EXISTS ansible_failed_jobs_sub;"
sudo -u postgres psql -d ansible_execution_results -c "DROP PUBLICATION IF EXISTS ansible_failed_jobs_pub;"

# Drop target database (CAUTION: This deletes all data!)
sudo -u postgres psql -c "DROP DATABASE IF EXISTS ansible_failed_jobs_vectordb;"

# Remove systemd services
sudo systemctl disable ddl-replication-worker postgres_exporter
sudo rm /etc/systemd/system/ddl-replication-worker.service
sudo rm /etc/systemd/system/postgres_exporter.service
sudo systemctl daemon-reload

# Remove worker script
sudo rm /usr/local/bin/replicate_ddl_changes.py
sudo rm /usr/local/bin/postgres_exporter

# Restore original PostgreSQL config (if you have backup)
# sudo cp /tmp/postgresql_cdc_backup_*/postgresql.conf /etc/postgresql/{version}/main/
# sudo systemctl restart postgresql
```

## Advanced Usage

### Semantic Search Examples

```sql
-- Find errors similar to a specific error message
SELECT 
  id,
  error_message,
  error_message_embedding <-> generate_embedding('connection timeout to database') as distance
FROM failed_jobs
WHERE error_message_embedding IS NOT NULL
ORDER BY distance
LIMIT 10;

-- Find all SSL-related errors using cosine similarity
SELECT 
  error_message, 
  1 - (error_message_embedding <=> generate_embedding('SSL certificate error')) as similarity
FROM failed_jobs
WHERE error_message_embedding IS NOT NULL
  AND (1 - (error_message_embedding <=> generate_embedding('SSL certificate error'))) > 0.7
ORDER BY similarity DESC;

-- Cluster similar errors
WITH error_clusters AS (
  SELECT 
    f1.id as id1,
    f2.id as id2,
    f1.error_message as msg1,
    f2.error_message as msg2,
    f1.error_message_embedding <-> f2.error_message_embedding as distance
  FROM failed_jobs f1
  CROSS JOIN failed_jobs f2
  WHERE f1.id < f2.id
    AND f1.error_message_embedding IS NOT NULL
    AND f2.error_message_embedding IS NOT NULL
)
SELECT msg1, msg2, distance
FROM error_clusters
WHERE distance < 0.2
ORDER BY distance
LIMIT 20;
```

### Custom Monitoring Queries

```sql
-- Replication health dashboard
SELECT 
  'Replication Lag' as metric,
  EXTRACT(EPOCH FROM (now() - last_msg_send_time)) || ' seconds' as value
FROM pg_stat_subscription
WHERE subname = 'ansible_failed_jobs_sub'
UNION ALL
SELECT 
  'Replication Slot Active',
  CASE WHEN active THEN 'Yes' ELSE 'No' END
FROM pg_replication_slots
WHERE slot_name = 'ansible_failed_jobs_sub'
UNION ALL
SELECT
  'Rows Replicated',
  COUNT(*)::TEXT
FROM failed_jobs;
```

## Support & Documentation

- **Installation Plan**: See `/memories/session/plan.md` for detailed architecture
- **Configuration Reference**: All settings documented in `configs/install_cdc_config.conf`
- **Script Documentation**: Inline comments in `install_cdc_replication.sh`
- **Ollama Documentation**: https://ollama.ai/
- **PostgreSQL Logical Replication**: https://www.postgresql.org/docs/current/logical-replication.html
- **pgVector Documentation**: https://github.com/pgvector/pgvector

## Performance Tuning

### For Large Data Volumes

```bash
# Increase batch size for faster backfill (in config)
EMBEDDING_BATCH_SIZE="500"

# Reduce throttle for faster processing
EMBEDDING_THROTTLE_SECONDS="0.5"

# Increase workers for faster replication
MAX_LOGICAL_REPLICATION_WORKERS="8"
```

### For Limited Resources

```bash
# Decrease batch size to reduce Ollama load
EMBEDDING_BATCH_SIZE="50"

# Increase throttle to reduce system load
EMBEDDING_THROTTLE_SECONDS="2"

# Use smaller embedding model (in config)
OLLAMA_MODEL="all-minilm"
EMBEDDING_DIMENSION="384"
```

## Security Best Practices

1. **Secure configuration files**:
   ```bash
   chmod 600 configs/install_cdc_config.conf
   ```

2. **Use strong passwords**:
   - PostgreSQL password should be 12+ characters
   - Include uppercase, lowercase, numbers, special characters

3. **Limit network exposure**:
   - Keep replication on localhost (default)
   - Use firewall rules for Prometheus port if exposing externally

4. **Regular backups**:
   ```bash
   # Backup both databases regularly
   pg_dump -U postgres ansible_execution_results > backup_source.sql
   pg_dump -U postgres ansible_failed_jobs_vectordb > backup_target.sql
   ```

5. **Monitor logs for suspicious activity**:
   ```bash
   sudo tail -f /var/log/postgresql/postgresql-*-main.log
   sudo tail -f /var/log/ddl_replication.log
   ```
