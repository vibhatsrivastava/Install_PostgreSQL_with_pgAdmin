# CDC (Change Data Capture) Replication with Vector Embeddings

Real-time PostgreSQL replication with automated vector embedding generation using Ollama AI models. Perfect for building semantic search systems with synchronized data.

## Overview

This CDC implementation extends PostgreSQL's logical replication with:

- ✅ **Automatic Vector Embeddings**: Generate semantic embeddings using Ollama AI models
- ✅ **DDL Replication**: Schema changes automatically propagate to target database
- ✅ **Prometheus Monitoring**: Track replication lag and performance metrics
- ✅ **Semantic Search Ready**: IVFFlat indexes for fast similarity search
- ✅ **Fault-Tolerant**: Automatic reconnection and error recovery

## Use Cases

- **AI-Powered Search**: Add semantic search to existing databases without modifying source
- **ML Training Data**: Automatically prepare training data with embeddings
- **Analytics & BI**: Real-time data replication for analytics workloads
- **Microservices**: Synchronize data across services with vector capabilities
- **Audit & Compliance**: Maintain synchronized audit trails with searchable embeddings

## Prerequisites

Before running CDC installation:

1. ✅ **PostgreSQL installed** (run `install_postgresql_pgadmin.sh` first)
2. ✅ **pgVector extension installed** (run `install_pgvector.sh`)
3. ✅ **Ollama running** with embedding models installed (local or remote)
4. ✅ **Source database exists** with tables containing text data
5. ✅ Root/sudo privileges

## Quick Start

### 1. Install Ollama and Pull Embedding Model

```bash
# Install Ollama (if not already installed)
curl -fsSL https://ollama.com/install.sh | sh

# Pull the embedding model (768 dimensions, optimized for semantic search)
ollama pull nomic-embed-text

# Verify model is available
ollama list
```

**For Docker Ollama:**
```bash
# If Ollama runs in Docker
docker exec -it <ollama-container> ollama pull nomic-embed-text
docker exec -it <ollama-container> ollama list
```

### 2. Configure CDC Settings

Edit the configuration file:

```bash
nano configs/install_cdc_config.conf
```

**Essential settings:**

```bash
# PostgreSQL superuser password (match configs/install_config.conf)
POSTGRES_PASSWORD="Admin@123"

# Source database (your existing database)
SOURCE_DATABASE="ansible_execution_results"

# Target database (will be created automatically)
TARGET_DATABASE="ansible_failed_jobs_vectordb"

# Source table to replicate
SOURCE_TABLE="failed_jobs"

# Column containing text to vectorize
TEXT_COLUMN_TO_VECTORIZE="message"

# Ollama API URL (local or remote)
OLLAMA_API_URL="http://localhost:11434"         # Local Ollama
# OLLAMA_API_URL="http://10.0.0.15:11434"      # Remote Ollama

# Embedding model from Ollama
OLLAMA_MODEL="nomic-embed-text"

# Embedding dimension (must match model)
EMBEDDING_DIMENSION="768"

# Feature toggles
ENABLE_DDL_REPLICATION="yes"
ENABLE_EMBEDDING_GENERATION="yes"
ENABLE_PROMETHEUS_MONITORING="yes"
```

### 3. Secure Configuration File

```bash
chmod 600 configs/install_cdc_config.conf
```

### 4. Run CDC Installation Script

```bash
chmod +x install_cdc_replication.sh
sudo ./install_cdc_replication.sh
```

The script will:
1. Configure PostgreSQL for logical replication
2. Create target database with pgvector extension
3. Set up publication and subscription
4. Install DDL replication daemon
5. Create embedding generation functions with trigger
6. Backfill embeddings for existing data
7. Install Prometheus monitoring
8. Verify entire setup

## Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| **PostgreSQL Settings** | | |
| `POSTGRES_VERSION` | Target PostgreSQL version | auto-detect |
| `POSTGRES_PASSWORD` | Superuser password | Admin@123 |
| **Replication Configuration** | | |
| `SOURCE_DATABASE` | Source database name | ansible_execution_results |
| `TARGET_DATABASE` | Target database name | ansible_failed_jobs_vectordb |
| `SOURCE_TABLE` | Table to replicate | failed_jobs |
| `TEXT_COLUMN_TO_VECTORIZE` | Column for embeddings | message |
| `PUBLICATION_NAME` | Publication name | ansible_failed_jobs_pub |
| `SUBSCRIPTION_NAME` | Subscription name | ansible_failed_jobs_sub |
| **Ollama Configuration** | | |
| `OLLAMA_API_URL` | Ollama API endpoint | http://localhost:11434 |
| `OLLAMA_MODEL` | Embedding model | nomic-embed-text |
| `EMBEDDING_DIMENSION` | Vector dimensions | 768 |
| `LLM_MODEL` | LLM model (future use) | gpt-oss:20b |
| **Feature Toggles** | | |
| `ENABLE_DDL_REPLICATION` | Auto DDL propagation | yes |
| `ENABLE_EMBEDDING_GENERATION` | Auto embeddings | yes |
| `ENABLE_PROMETHEUS_MONITORING` | Metrics export | yes |
| **Performance Settings** | | |
| `EMBEDDING_BATCH_SIZE` | Backfill batch size | 100 |
| `EMBEDDING_THROTTLE_SECONDS` | Delay between batches | 1 |
| `MAX_TEXT_LENGTH` | Max text chars | 8000 |
| `DDL_POLL_INTERVAL_SECONDS` | DDL check interval | 30 |

## How CDC Replication Works

### 1. Logical Replication (PostgreSQL Native)

```
Source DB → Publication → Replication Slot → Subscription → Target DB
```

- Real-time data streaming via PostgreSQL WAL
- Row-level replication (INSERT/UPDATE/DELETE)
- Minimal latency (typically <1 second)

### 2. DDL Replication (Event Trigger + Python Daemon)

```
Source DB → Event Trigger → DDL Log → Python Worker → Target DB
```

- Captures schema changes (ALTER TABLE, ADD COLUMN, etc.)
- Asynchronous propagation via Python daemon
- Runs as systemd service: `ddl-replication-worker.service`

### 3. Vector Embedding Generation (PL/Python + Ollama)

```
New Row → PostgreSQL Trigger → PL/Python Function → Ollama API → Vector Storage
```

- Automatic on INSERT/UPDATE
- Calls Ollama API for embeddings
- Stores 768-dim vectors in pgvector column
- Creates IVFFlat index for fast similarity search

### 4. Monitoring (Prometheus + postgres_exporter)

```
PostgreSQL → postgres_exporter → Prometheus → Metrics
```

- Exposed on port 9187 by default
- Metrics: replication lag, subscription state, error counts

## Using CDC for Semantic Search

After CDC setup, query similar records using vector similarity:

```sql
-- Connect to target database
\c ansible_failed_jobs_vectordb

-- Search for similar error messages
SELECT 
    id,
    message,
    1 - (message_embedding <=> generate_embedding('connection timeout error')) as similarity
FROM failed_jobs
WHERE message_embedding IS NOT NULL
ORDER BY message_embedding <=> generate_embedding('connection timeout error')
LIMIT 10;

-- Alternative: Use cosine distance operator
SELECT *
FROM failed_jobs
ORDER BY message_embedding <-> generate_embedding('database locked')
LIMIT 5;
```

**Distance Operators:**
- `<->`: Cosine distance (0 = identical, 2 = opposite)
- `<=>`: Euclidean distance (L2)
- `<#>`: Inner product

## Monitoring and Management

### Check Replication Status

```bash
# Subscription status
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT 
    subname, 
    subenabled, 
    (SELECT srsubstate FROM pg_subscription_rel WHERE srsubid = s.oid LIMIT 1) as state
FROM pg_subscription s;"

# Replication lag
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT 
    subname,
    now() - last_msg_send_time as lag 
FROM pg_stat_subscription;"

# Row count comparison
echo "Source:" && sudo -u postgres psql -t -d ansible_execution_results -c "SELECT COUNT(*) FROM failed_jobs;"
echo "Target:" && sudo -u postgres psql -t -d ansible_failed_jobs_vectordb -c "SELECT COUNT(*) FROM failed_jobs;"
```

### Check DDL Worker Status

```bash
# Service status
sudo systemctl status ddl-replication-worker

# View logs
sudo tail -f /var/log/ddl_replication.log

# Restart worker
sudo systemctl restart ddl-replication-worker
```

### Check Embedding Generation

```bash
# Count embedded rows
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT 
    COUNT(*) as total_rows,
    COUNT(message_embedding) as embedded_rows,
    COUNT(*) - COUNT(message_embedding) as pending_embeddings
FROM failed_jobs;"

# Test embedding function
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT array_length(generate_embedding('test query')::real[], 1) as dimension;"
```

### Prometheus Metrics

```bash
# View all metrics
curl http://localhost:9187/metrics

# Replication-specific metrics
curl http://localhost:9187/metrics | grep pg_replication

# Subscription state
curl http://localhost:9187/metrics | grep pg_stat_subscription
```

## Troubleshooting

### Replication Not Starting

**Symptom:** Subscription exists but no data replicates

```bash
# Check publication
sudo -u postgres psql -d ansible_execution_results -c "
SELECT * FROM pg_publication WHERE pubname = 'ansible_failed_jobs_pub';"

# Check replication slot
sudo -u postgres psql -c "
SELECT * FROM pg_replication_slots WHERE slot_name = 'ansible_failed_jobs_sub';"

# Check PostgreSQL logs
sudo tail -50 /var/log/postgresql/postgresql-16-main.log
```

**Solution:**
- Ensure `wal_level = logical` in PostgreSQL configuration
- Restart PostgreSQL if wal_level was changed
- Check for old transaction IDs blocking slot creation

### Embeddings Not Generating

**Symptom:** `message_embedding` column is NULL

```bash
# Test Ollama connection
curl http://localhost:11434/api/tags

# Test embedding function manually
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT generate_embedding('test');"

# Check for errors in PostgreSQL logs
sudo tail -50 /var/log/postgresql/postgresql-16-main.log | grep embedding
```

**Solution:**
- Verify Ollama is running: `systemctl status ollama` or check Docker container
- Ensure model is pulled: `ollama list`
- Check Ollama API URL in config
- Verify plpython3u extension is installed
- Test network connectivity to remote Ollama if applicable

### DDL Changes Not Propagating

**Symptom:** Schema changes in source don't appear in target

```bash
# Check DDL worker service
sudo systemctl status ddl-replication-worker

# Check DDL logs
sudo tail -50 /var/log/ddl_replication.log

# Check event trigger
sudo -u postgres psql -d ansible_execution_results -c "
SELECT * FROM pg_event_trigger WHERE evtname = 'replicate_ddl_trigger';"

# Check pending DDL changes
sudo -u postgres psql -d ansible_execution_results -c "
SELECT * FROM ddl_replication_log ORDER BY id DESC LIMIT 10;"
```

**Solution:**
- Restart DDL worker: `sudo systemctl restart ddl-replication-worker`
- Check Python dependencies: `pip3 list | grep psycopg2`
- Verify source database permissions

### High Replication Lag

**Symptom:** Target database is behind source

```bash
# Check subscription lag
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
SELECT 
    now() - last_msg_send_time as lag,
    received_lsn,
    latest_end_lsn 
FROM pg_stat_subscription;"

# Check for long-running transactions
sudo -u postgres psql -d ansible_execution_results -c "
SELECT * FROM pg_stat_activity WHERE state != 'idle' ORDER BY xact_start;"
```

**Solution:**
- Increase `max_wal_senders` and `max_replication_slots`
- Optimize embedding generation (increase `EMBEDDING_THROTTLE_SECONDS`)
- Check network latency for remote Ollama
- Consider batching embedding generation separately

## Cleanup and Removal

To remove CDC replication setup:

```bash
# Use the cleanup script
sudo ./cleanup_stuck_installation.sh
```

Or manually:

```bash
# Stop DDL worker
sudo systemctl stop ddl-replication-worker
sudo systemctl disable ddl-replication-worker
sudo rm /etc/systemd/system/ddl-replication-worker.service

# Drop subscription (in target)
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
DROP SUBSCRIPTION IF EXISTS ansible_failed_jobs_sub;"

# Drop publication (in source)
sudo -u postgres psql -d ansible_execution_results -c "
DROP PUBLICATION IF EXISTS ansible_failed_jobs_pub;"

# Drop replication slot
sudo -u postgres psql -d ansible_execution_results -c "
SELECT pg_drop_replication_slot('ansible_failed_jobs_sub');"

# Drop target database
sudo -u postgres psql -c "
DROP DATABASE IF EXISTS ansible_failed_jobs_vectordb;"

# Stop Prometheus exporter
sudo systemctl stop postgres_exporter
sudo systemctl disable postgres_exporter
```

## Best Practices

1. **Monitor Replication Lag**: Set up alerts for lag > 10 seconds
2. **Index Strategy**: Create indexes on target database for query performance
3. **Embedding Batching**: For large backfills, increase throttle delay
4. **Resource Allocation**: Ollama embedding generation is CPU-intensive
5. **Network Reliability**: Use reliable connection for remote Ollama
6. **Backup Strategy**: Regular backups of both source and target databases
7. **Testing**: Test CDC setup in development before production deployment

## Performance Considerations

**Embedding Generation:**
- ~100-200ms per text (varies by model and hardware)
- Batch processing recommended for large datasets
- Consider dedicated Ollama instance for production

**Replication Throughput:**
- Standard logical replication: 1000-5000 rows/sec
- With embeddings: 10-50 rows/sec (limited by Ollama API)
- DDL replication: Near real-time (< 1 minute)

**Resource Usage:**
- DDL worker: ~10MB RAM, minimal CPU
- Prometheus exporter: ~20MB RAM
- Embedding generation: CPU-intensive (Ollama side)

---

**Related Documentation:**
- [Configuration Reference](CONFIGURATION.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Performance Tuning](PERFORMANCE_TUNING.md)
- [Back to Main README](../README.md)
