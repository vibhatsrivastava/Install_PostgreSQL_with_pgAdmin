# PostgreSQL and pgAdmin4 Installation for Ubuntu 24.04

Automated installation script for PostgreSQL database server and pgAdmin4 web interface on Ubuntu 24.04 LTS.

## Features

- ✅ Automated PostgreSQL installation and configuration
- ✅ pgAdmin4 Web interface setup
- ✅ **pgVector extension for AI/ML vector similarity search**
- ✅ **CDC (Change Data Capture) Replication with Vector Embeddings**
- ✅ **Automated DDL propagation between databases**
- ✅ **Real-time vector embedding generation via Ollama**
- ✅ **Prometheus monitoring for replication metrics**
- ✅ Custom database and user creation
- ✅ Optional remote access configuration
- ✅ **Intelligent performance tuning with auto-detection**
- ✅ **SSD/HDD disk type optimization**
- ✅ **Apache reverse proxy with custom domain support (optional)**
- ✅ **Self-signed SSL certificate generation for HTTPS (optional)**
- ✅ **pgAdmin upgrade utility with automatic rollback**
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

## CDC (Change Data Capture) Replication with Vector Embeddings

**NEW!** The repository now includes an advanced CDC replication system that combines PostgreSQL logical replication with automated vector embedding generation via Ollama. Perfect for creating AI-powered semantic search systems with real-time data synchronization.

### What is CDC Replication?

Change Data Capture (CDC) automatically replicates data changes from a source PostgreSQL database to a target database in real-time. This implementation extends standard CDC with:

- ✅ **Automatic Vector Embeddings**: Generate semantic embeddings using Ollama AI models
- ✅ **DDL Replication**: Schema changes automatically propagate to target database
- ✅ **Prometheus Monitoring**: Track replication lag and performance metrics
- ✅ **Semantic Search Ready**: IVFFlat indexes for fast similarity search
- ✅ **Fault-Tolerant**: Automatic reconnection and error recovery

### Use Cases

- **AI-Powered Search**: Add semantic search to existing databases without modifying source
- **ML Training Data**: Automatically prepare training data with embeddings
- **Analytics & BI**: Real-time data replication for analytics workloads
- **Microservices**: Synchronize data across services with vector capabilities
- **Audit & Compliance**: Maintain synchronized audit trails with searchable embeddings

### Prerequisites for CDC Setup

Before running CDC installation:

1. ✅ **PostgreSQL installed** (run `install_postgresql_pgadmin.sh` first)
2. ✅ **pgVector extension installed** (run `install_pgvector.sh`)
3. ✅ **Ollama running** with embedding models installed (local or remote)
4. ✅ **Source database exists** with tables containing text data
5. ✅ Root/sudo privileges

### Quick Start: CDC Installation

#### 1. Install Ollama and Pull Embedding Model

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

#### 2. Configure CDC Settings

Edit the `configs/install_cdc_config.conf` file:

```bash
nano configs/install_cdc_config.conf
```

**Essential settings:**

```bash
# PostgreSQL superuser password (match install_config.conf)
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

#### 3. Secure Configuration File

```bash
chmod 600 configs/install_cdc_config.conf
```

#### 4. Run CDC Installation Script

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

### CDC Configuration Options

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

### How CDC Replication Works

#### 1. **Logical Replication (PostgreSQL Native)**
```
Source DB → Publication → Replication Slot → Subscription → Target DB
```

- Real-time data streaming via PostgreSQL WAL
- Row-level replication (INSERT/UPDATE/DELETE)
- Minimal latency (typically <1 second)

#### 2. **DDL Replication (Event Trigger + Python Daemon)**
```
Source DB → Event Trigger → DDL Log → Python Worker → Target DB
```

- Captures schema changes (ALTER TABLE, ADD COLUMN, etc.)
- Asynchronous propagation via Python daemon
- Runs as systemd service: `ddl-replication-worker.service`

#### 3. **Vector Embedding Generation (PL/Python + Ollama)**
```
New Row → PostgreSQL Trigger → PL/Python Function → Ollama API → Vector Storage
```

- Automatic on INSERT/UPDATE
- Calls Ollama API for embeddings
- Stores 768-dim vectors in pgvector column
- Creates IVFFlat index for fast similarity search

#### 4. **Monitoring (Prometheus + postgres_exporter)**
```
PostgreSQL → postgres_exporter → Prometheus → Metrics
```

- Exposed on port 9187 by default
- Metrics: replication lag, subscription state, error counts

### CDC Architecture Diagram

```
┌─────────────────────┐         ┌──────────────────────┐
│   Source Database   │         │   Target Database    │
│  (Production Data)  │         │  (Vector-Enhanced)   │
└──────────┬──────────┘         └──────────┬───────────┘
           │                               │
           │ ┌─────────────────┐           │
           ├─┤ Publication     │           │
           │ │ (Table Changes) │           │
           │ └─────────────────┘           │
           │                               │
           │ ┌─────────────────┐           │
           ├─┤ Event Trigger   │           │
           │ │ (DDL Changes)   │           │
           │ └────────┬────────┘           │
           │          │                    │
           │          ▼                    │
           │  [DDL Log Table]              │
           │          │                    │
           │          ▼                    │
           │   ┌──────────────┐            │
           │   │ Python Worker│            │
           │   │   (Daemon)   │────────────┤
           │   └──────────────┘            │
           │                               │
           │ ┌─────────────────┐           │
           └─┤ Subscription    │───────────┤
             └─────────────────┘           │
                                           │
                                           ▼
                                   [Replicated Data]
                                           +
                                   [Vector Column]
                                           ▲
                                           │
                                   ┌───────┴────────┐
                                   │ Embedding      │
                                   │ Trigger +      │
                                   │ PL/Python      │
                                   └───────┬────────┘
                                           │
                                   ┌───────▼────────┐
                                   │ Ollama API     │
                                   │ (nomic-embed)  │
                                   └────────────────┘
```

### Using CDC for Semantic Search

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

### CDC Monitoring and Management

#### Check Replication Status

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

#### Check DDL Worker Status

```bash
# Service status
sudo systemctl status ddl-replication-worker

# View logs
sudo tail -f /var/log/ddl_replication.log

# Restart worker
sudo systemctl restart ddl-replication-worker
```

#### Check Embedding Generation

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

#### Prometheus Metrics

```bash
# View all metrics
curl http://localhost:9187/metrics

# Replication-specific metrics
curl http://localhost:9187/metrics | grep pg_replication

# Subscription state
curl http://localhost:9187/metrics | grep pg_stat_subscription
```

### CDC Troubleshooting

#### Replication Not Starting

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

#### Embeddings Not Generating

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

#### DDL Changes Not Propagating

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

#### High Replication Lag

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

### CDC Cleanup and Removal

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

### CDC Best Practices

1. **Monitor Replication Lag**: Set up alerts for lag > 10 seconds
2. **Index Strategy**: Create indexes on target database for query performance
3. **Embedding Batching**: For large backfills, increase throttle delay
4. **Resource Allocation**: Ollama embedding generation is CPU-intensive
5. **Network Reliability**: Use reliable connection for remote Ollama
6. **Backup Strategy**: Regular backups of both source and target databases
7. **Testing**: Test CDC setup in development before production deployment

### Performance Considerations

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
| `TARGET_VERSION` | Version to upgrade to ("latest" or specific) | latest |
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

**What Gets Restored (Guaranteed):**

Manual rollback always restores:
- ✅ **Configuration Files**: All pgAdmin configuration from `/etc/pgadmin/`
- ✅ **User Data**: Server connections and preferences from `/var/lib/pgadmin/`
- ✅ **Apache Configuration**: WSGI and VirtualHost configurations
- ✅ **SSL Certificates**: All SSL certificates if they were backed up
- ✅ **Service Restart**: Apache is restarted and accessibility verified

**Package Downgrade (Conditional):**

The script will **attempt to downgrade** the pgAdmin package to the previous version, but this requires:
- The backup contains a valid `system_state.txt` file
- Version information can be successfully extracted from the backup

**If version information is missing or invalid**, the script will:
- ⚠️ Display a warning that package downgrade was skipped
- ✅ Continue to restore all configurations and data (guaranteed above)
- ℹ️ Provide the manual command to downgrade the package

**Manual Package Downgrade** (if automatic downgrade fails):
```bash
# Check available versions
apt-cache policy pgadmin4-web

# Downgrade to specific version (use version from backup or desired version)
sudo apt-get install -y --allow-downgrades pgadmin4-web=<version>

# Example: Downgrade to version 8.12
sudo apt-get install -y --allow-downgrades pgadmin4-web=8.12-1
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
sudo find /tmp -name "pgadmin_upgrade_backup_*" -type d -mtime +30 -exec rm -rf {} +
```

## Installing pgVector Extension

The `install_pgvector.sh` script provides an automated way to install and configure the [pgvector](https://github.com/pgvector/pgvector) extension for PostgreSQL, enabling vector similarity search capabilities for AI/ML applications, semantic search, and recommendation systems.

### What is pgVector?

pgvector is a PostgreSQL extension that adds support for:
- **Vector data types**: Store embeddings from machine learning models
- **Vector similarity search**: Find similar items using L2 distance, inner product, or cosine similarity
- **Indexing**: Fast approximate nearest neighbor search using IVFFlat or HNSW indexes
- **Integration**: Works seamlessly with popular ML frameworks (OpenAI, Hugging Face, etc.)

### Features

- ✅ **Automated Installation**: Installs pgvector package for your PostgreSQL version
- ✅ **Selective Database Configuration**: Enable pgvector in specific databases
- ✅ **Template Database Support**: Optionally enable for all future databases
- ✅ **Comprehensive Verification**: Tests vector operations, similarity search, and indexing
- ✅ **Automatic Rollback**: Reverts changes on installation failure
- ✅ **Easy Uninstall**: Complete removal with `--uninstall` flag
- ✅ **Version Auto-Detection**: Automatically detects PostgreSQL version

### Prerequisites

- ✅ PostgreSQL must be already installed and running
- ✅ Root or sudo access
- ✅ Internet connection for downloading packages
- ✅ Ubuntu 24.04 LTS (recommended)

### Quick Installation Guide

#### 1. Configure pgVector Settings

Edit the `configs/install_pgvector_config.conf` file:

```bash
nano configs/install_pgvector_config.conf
```

**Important settings:**

```bash
# PostgreSQL version (leave empty for auto-detect)
POSTGRES_VERSION=""

# Databases to enable pgvector in (comma-separated)
TARGET_DATABASES="postgres,myappdb"

# Enable in template1 for all future databases
ENABLE_IN_TEMPLATE1="no"

# Run verification tests after installation
RUN_VERIFICATION_TESTS="yes"
```

#### 2. Secure Configuration File

```bash
chmod 600 configs/install_pgvector_config.conf
```

#### 3. Run Installation Script

```bash
chmod +x install_pgvector.sh
sudo ./install_pgvector.sh
```

The script will:
- Check that PostgreSQL is installed and running
- Auto-detect PostgreSQL version
- Install the appropriate pgvector package
- Enable the extension in specified databases
- Run comprehensive verification tests
- Display success information and usage examples

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `POSTGRES_VERSION` | PostgreSQL version to target | (auto-detect) |
| `TARGET_DATABASES` | Comma-separated list of databases | postgres |
| `ENABLE_IN_TEMPLATE1` | Enable for all future databases | no |
| `RUN_VERIFICATION_TESTS` | Run tests after installation | yes |
| `TEST_VECTOR_DIMENSION` | Dimension for test vectors | 3 |
| `LOG_FILE` | Log file location | /var/log/pgvector_install_*.log |
| `VERBOSE_LOGGING` | Show detailed PostgreSQL output | no |

### Using pgVector

After installation, you can use vector operations in your databases:

#### Create Table with Vector Column

```sql
-- Connect to your database
\c myappdb

-- Create table with vector column (e.g., 1536 dimensions for OpenAI embeddings)
CREATE TABLE documents (
    id bigserial PRIMARY KEY,
    content text,
    embedding vector(1536)
);
```

#### Insert Vectors

```sql
-- Insert sample vectors
INSERT INTO documents (content, embedding) VALUES
    ('Document 1', '[0.1, 0.2, 0.3, ...]'),  -- 1536 dimensions
    ('Document 2', '[0.4, 0.5, 0.6, ...]');
```

#### Similarity Search

```sql
-- Find most similar documents using L2 distance
SELECT content, embedding <-> '[0.1, 0.2, 0.3, ...]' AS distance
FROM documents
ORDER BY distance
LIMIT 5;

-- Using cosine distance (recommended for normalized vectors)
SELECT content, embedding <=> '[0.1, 0.2, 0.3, ...]' AS cosine_distance
FROM documents
ORDER BY cosine_distance
LIMIT 5;

-- Using inner product (for maximum inner product search)
SELECT content, (embedding <#> '[0.1, 0.2, 0.3, ...]') * -1 AS inner_product
FROM documents
ORDER BY embedding <#> '[0.1, 0.2, 0.3, ...]'
LIMIT 5;
```

#### Create Index for Fast Search

```sql
-- Create HNSW index (better recall, requires pgvector >= 0.5.0)
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops);

-- Or IVFFlat index (faster build time)
CREATE INDEX ON documents USING ivfflat (embedding vector_l2_ops) WITH (lists = 100);
```

### Distance Operators

| Operator | Description | Order By | Index Operator |
|----------|-------------|----------|----------------|
| `<->` | L2 distance (Euclidean) | ASC | `vector_l2_ops` |
| `<#>` | Inner product (negative) | ASC | `vector_ip_ops` |
| `<=>` | Cosine distance | ASC | `vector_cosine_ops` |

### Verification Tests

When `RUN_VERIFICATION_TESTS="yes"`, the script performs:

1. **Package Check**: Verifies pgvector package installation
2. **Extension Check**: Confirms extension is enabled
3. **Vector Operations**: Tests creating vectors and basic operations
4. **L2 Distance**: Tests Euclidean distance calculations
5. **Inner Product**: Tests cosine similarity calculations
6. **IVFFlat Index**: Tests approximate nearest neighbor indexing
7. **HNSW Index**: Tests hierarchical navigable small world indexing (if available)

All tests are performed on temporary tables that are automatically cleaned up.

### Uninstalling pgVector

To completely remove pgvector extension:

```bash
# Uninstall with confirmation
sudo ./install_pgvector.sh --uninstall

# Uninstall without confirmation
sudo ./install_pgvector.sh --uninstall --force
```

The uninstall process:
- Detects all databases with pgvector extension
- Drops the extension from each database (with CASCADE)
- Removes the pgvector package
- Cleans up dependencies

### Command-Line Options

```bash
# Install pgvector (default)
sudo ./install_pgvector.sh

# Uninstall pgvector with confirmation
sudo ./install_pgvector.sh --uninstall

# Uninstall without confirmation prompt
sudo ./install_pgvector.sh --uninstall --force

# Display help information
sudo ./install_pgvector.sh --help
```

### Common Use Cases

#### OpenAI Embeddings

```sql
-- Table for OpenAI ada-002 embeddings (1536 dimensions)
CREATE TABLE openai_embeddings (
    id bigserial PRIMARY KEY,
    text text,
    embedding vector(1536)
);

-- Create index for fast similarity search
CREATE INDEX ON openai_embeddings USING hnsw (embedding vector_cosine_ops);

-- Find similar texts
SELECT text, embedding <=> $1 AS similarity
FROM openai_embeddings
ORDER BY similarity
LIMIT 10;
```

#### Sentence Transformers / Hugging Face

```sql
-- Table for sentence-transformers embeddings (384 dimensions for all-MiniLM-L6-v2)
CREATE TABLE sentence_embeddings (
    id bigserial PRIMARY KEY,
    sentence text,
    embedding vector(384)
);

-- Create index
CREATE INDEX ON sentence_embeddings USING hnsw (embedding vector_cosine_ops);
```

#### Product Recommendations

```sql
-- Table for product feature vectors
CREATE TABLE products (
    id bigserial PRIMARY KEY,
    name text,
    description text,
    feature_vector vector(128)
);

-- Find similar products
SELECT p.name, p.feature_vector <-> $1 AS distance
FROM products p
ORDER BY distance
LIMIT 5;
```

### Integration Examples

#### Python with psycopg2

```python
import psycopg2
import numpy as np

# Connect to database
conn = psycopg2.connect("dbname=myappdb user=postgres")
cur = conn.cursor()

# Insert vector
embedding = np.random.rand(1536).tolist()
cur.execute(
    "INSERT INTO documents (content, embedding) VALUES (%s, %s)",
    ("Sample document", embedding)
)

# Search similar vectors
query_vector = np.random.rand(1536).tolist()
cur.execute(
    "SELECT content FROM documents ORDER BY embedding <=> %s LIMIT 5",
    (query_vector,)
)
results = cur.fetchall()
```

#### Python with SQLAlchemy

```python
from sqlalchemy import create_engine, text
from pgvector.sqlalchemy import Vector

# Create engine
engine = create_engine('postgresql://postgres@localhost/myappdb')

# Execute similarity search
with engine.connect() as conn:
    result = conn.execute(
        text("SELECT content FROM documents ORDER BY embedding <=> :embedding LIMIT 5"),
        {"embedding": embedding}
    )
```

### Troubleshooting pgVector

#### Extension Not Found

If you see "extension 'vector' is not available":

```bash
# Check if package is installed
dpkg -l | grep pgvector

# Check PostgreSQL version
sudo -u postgres psql -c "SHOW server_version;"

# Reinstall for correct version
sudo apt-get install postgresql-16-pgvector  # Replace 16 with your version
```

#### Index Creation Fails

For IVFFlat indexes, you need enough data:

```sql
-- IVFFlat requires at least 'lists' number of rows
-- For lists=100, you need at least 100 rows

-- Alternative: Use HNSW index (no minimum data requirement)
CREATE INDEX ON table USING hnsw (embedding vector_cosine_ops);
```

#### Version Compatibility

- **pgvector >= 0.5.0**: HNSW index support
- **pgvector >= 0.4.0**: Cosine distance operator
- **pgvector >= 0.1.0**: Basic vector operations

Check your version:

```sql
SELECT extversion FROM pg_extension WHERE extname = 'vector';
```

### Performance Tips

1. **Choose the Right Index**:
   - HNSW: Better recall, good for most use cases
   - IVFFlat: Faster build time, good for large datasets

2. **Normalize Vectors**: Use cosine distance for normalized vectors

3. **Tune Index Parameters**:
   ```sql
   -- IVFFlat: lists = rows / 1000 (for rows > 1M)
   CREATE INDEX ON table USING ivfflat (embedding vector_cosine_ops) WITH (lists = 1000);
   
   -- HNSW: m (connections per layer), ef_construction (build quality)
   CREATE INDEX ON table USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);
   ```

4. **Use Connection Pooling**: For high-concurrency applications

5. **Batch Operations**: Insert/update vectors in batches

### Resources

- **pgvector GitHub**: https://github.com/pgvector/pgvector
- **Documentation**: https://github.com/pgvector/pgvector#readme
- **Performance Guide**: https://github.com/pgvector/pgvector#performance
- **Language Libraries**: https://github.com/pgvector/pgvector#languages

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
├── install_postgresql_pgadmin.sh       # PostgreSQL & pgAdmin installation script
├── install_pgvector.sh                 # pgVector extension installation script
├── install_cdc_replication.sh          # CDC replication with vector embeddings
├── cleanup_stuck_installation.sh       # CDC cleanup and rollback utility
├── install_apache_reverse_proxy.sh     # Apache reverse proxy setup script
├── upgrade_pgadmin.sh                  # pgAdmin upgrade utility script
├── configs/
│   ├── install_config.conf             # Main installation configuration
│   ├── install_pgvector_config.conf    # pgVector installation configuration
│   ├── install_cdc_config.conf         # CDC replication configuration
│   ├── install_config_proxy.conf       # Reverse proxy configuration
│   └── upgrade_pgadmin_config.conf     # pgAdmin upgrade configuration
├── README.md                           # This file
├── CDC_QUICKSTART.md                   # CDC quick reference guide
└── .gitignore                          # Git ignore file
```

## Version Information

- **Script Version**: 1.3.0
- **Supported OS**: Ubuntu 24.04 LTS
- **PostgreSQL**: Latest available in Ubuntu repos (typically 16+)
- **pgAdmin**: Latest from official pgAdmin repository
- **pgVector**: Latest from official pgvector repository
- **Ollama**: For CDC vector embedding generation

## Support and Contributing

For issues, questions, or contributions:
- Check troubleshooting section above
- Review log files for detailed error information
- Ensure all prerequisites are met

## License

This script is provided as-is for educational and production use.

## Changelog

### Version 1.3.0 (2025-02-19)
- **Added CDC (Change Data Capture) replication system**
- **Automated vector embedding generation with Ollama AI**
- **Logical replication with pgVector extension**
- **DDL replication daemon for schema synchronization**
- **Prometheus monitoring integration**
- **Semantic search capabilities with IVFFlat indexing**
- Six critical bug fixes for production readiness:
  - Ollama model detection pattern matching
  - Database connection conflict resolution
  - Replication slot timeout with VACUUM FREEZE
  - Ubuntu 24.04 pip externally-managed environment
  - PL/Python parameter scoping
  - Bash heredoc syntax for multi-line strings
- New scripts: `install_cdc_replication.sh`, `cleanup_stuck_installation.sh`
- New config: `configs/install_cdc_config.conf`
- Comprehensive CDC documentation with troubleshooting guide

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
