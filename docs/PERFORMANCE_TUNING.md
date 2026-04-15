# PostgreSQL Performance Tuning Guide

Intelligent performance optimization that automatically configures PostgreSQL based on your system's hardware resources.

## Overview

The installation script includes intelligent performance tuning that automatically optimizes PostgreSQL based on:

- **Total system RAM**
- **Number of CPU cores**
- **Disk type** (SSD vs HDD)

This guide covers performance profiles, optimization strategies, and use-case specific configurations.

## How It Works

### 1. Auto-Detection

The script automatically detects:
- Total system RAM
- Number of CPU cores
- Disk type (SSD vs HDD)

### 2. Profile Selection

Based on detected resources, it selects an optimal profile:
- **low**: For systems with 1-2GB RAM
- **medium**: For systems with 2-8GB RAM
- **high**: For systems with 8GB+ RAM

### 3. Optimization

Applies 11 PostgreSQL parameters optimized for your hardware

## Performance Profiles

### Auto Profile (Recommended)

Automatically selects the best profile based on available RAM:

```bash
# In configs/install_config.conf
APPLY_PERFORMANCE_TUNING="yes"
PERFORMANCE_PROFILE="auto"
```

### Low Profile (1-2GB RAM)

Optimized for smaller systems and light workloads:

| Parameter | Value |
|-----------|-------|
| `shared_buffers` | 256MB |
| `effective_cache_size` | 1GB |
| `work_mem` | 4MB |
| `max_connections` | 100 |

```bash
PERFORMANCE_PROFILE="low"
```

### Medium Profile (2-8GB RAM)

Balanced settings for typical applications:

| Parameter | Value |
|-----------|-------|
| `shared_buffers` | 1GB |
| `effective_cache_size` | 3GB |
| `work_mem` | 16MB |
| `max_connections` | 200 |

```bash
PERFORMANCE_PROFILE="medium"
```

### High Profile (8GB+ RAM)

Maximum performance for high-traffic applications:

| Parameter | Value |
|-----------|-------|
| `shared_buffers` | 25% of total RAM |
| `effective_cache_size` | 75% of total RAM |
| `work_mem` | 32MB |
| `max_connections` | 300 |

```bash
PERFORMANCE_PROFILE="high"
```

### Custom Profile

Fine-tune individual parameters for specific needs:

```bash
PERFORMANCE_PROFILE="custom"
CUSTOM_SHARED_BUFFERS="2GB"
CUSTOM_EFFECTIVE_CACHE_SIZE="6GB"
CUSTOM_WORK_MEM="16MB"
CUSTOM_MAX_CONNECTIONS="150"
CUSTOM_MAX_WAL_SIZE="2GB"
CUSTOM_MIN_WAL_SIZE="1GB"
CUSTOM_CHECKPOINT_COMPLETION_TARGET="0.9"
CUSTOM_WAL_BUFFERS="16MB"
CUSTOM_DEFAULT_STATISTICS_TARGET="100"
CUSTOM_RANDOM_PAGE_COST="1.1"          # 1.1 for SSD, 4.0 for HDD
CUSTOM_EFFECTIVE_IO_CONCURRENCY="200"  # 200 for SSD, 2 for HDD
```

## SSD vs HDD Optimization

The script automatically detects your disk type and optimizes accordingly:

### SSD Optimization

```
random_page_cost = 1.1           (default: 4.0)
effective_io_concurrency = 200   (default: 2)
```

**Why?** SSDs have much faster random access and can handle many concurrent I/O operations.

### HDD Optimization

```
random_page_cost = 4.0
effective_io_concurrency = 2
```

**Why?** HDDs have slower random access and limited concurrent I/O capability.

## Parameters Explained

### Memory Settings

| Parameter | Description | Impact |
|-----------|-------------|--------|
| `shared_buffers` | PostgreSQL's shared memory buffer pool | Main cache for data |
| `effective_cache_size` | OS and PostgreSQL cache estimation | Query planner decisions |
| `maintenance_work_mem` | Memory for maintenance operations | VACUUM, CREATE INDEX speed |
| `work_mem` | Memory per query operation | Sorting, hashing operations |

### Connection Settings

| Parameter | Description | Impact |
|-----------|-------------|--------|
| `max_connections` | Maximum concurrent connections | Memory allocation per connection |

### Write-Ahead Log (WAL)

| Parameter | Description | Impact |
|-----------|-------------|--------|
| `max_wal_size` | Maximum WAL size before checkpoint | Write performance, checkpoint frequency |
| `min_wal_size` | Minimum WAL size to maintain | Space management |
| `checkpoint_completion_target` | Checkpoint timing (0.0-1.0) | I/O spreading |
| `wal_buffers` | WAL buffer size | Write throughput |

### Query Planner

| Parameter | Description | Impact |
|-----------|-------------|--------|
| `default_statistics_target` | Query planning statistics detail | Query optimization quality |
| `random_page_cost` | Cost estimate for random disk operations | Index vs seq scan decisions |
| `effective_io_concurrency` | Concurrent I/O operations | Parallel query performance |

## Use Case-Specific Configurations

### High-Volume Inserts

For applications with hundreds of concurrent inserts (e.g., logging systems):

```bash
PERFORMANCE_PROFILE="custom"
CUSTOM_SHARED_BUFFERS="2GB"
CUSTOM_WORK_MEM="16MB"
CUSTOM_MAX_CONNECTIONS="300"          # High concurrent connections
CUSTOM_MAX_WAL_SIZE="4GB"             # Larger WAL for write-heavy loads
CUSTOM_MIN_WAL_SIZE="2GB"
CUSTOM_CHECKPOINT_COMPLETION_TARGET="0.9"  # Smooth checkpoints
CUSTOM_WAL_BUFFERS="32MB"             # Larger WAL buffers
```

**Additional recommendations:**
- Use connection pooling (pgBouncer)
- Implement table partitioning for large tables
- Batch inserts (100-500 rows per INSERT statement)
- Consider unlogged tables for temporary data

### Read-Heavy Applications

For applications with mostly SELECT queries:

```bash
PERFORMANCE_PROFILE="custom"
CUSTOM_SHARED_BUFFERS="4GB"
CUSTOM_EFFECTIVE_CACHE_SIZE="12GB"    # Large cache for read performance
CUSTOM_WORK_MEM="32MB"                # More memory for complex queries
CUSTOM_MAX_CONNECTIONS="100"
CUSTOM_DEFAULT_STATISTICS_TARGET="150" # Better query planning
```

**Additional recommendations:**
- Create appropriate indexes
- Use materialized views for complex aggregations
- Consider read replicas for scaling

### Mixed Workloads

For general-purpose applications:

```bash
PERFORMANCE_PROFILE="auto"  # Recommended for most cases
```

The auto profile provides balanced settings suitable for most workloads.

### OLAP/Analytics

For data warehouse and analytics workloads:

```bash
PERFORMANCE_PROFILE="custom"
CUSTOM_SHARED_BUFFERS="8GB"
CUSTOM_EFFECTIVE_CACHE_SIZE="24GB"
CUSTOM_WORK_MEM="64MB"                # Large for complex queries
CUSTOM_MAINTENANCE_WORK_MEM="2GB"     # Fast VACUUM, CREATE INDEX
CUSTOM_MAX_CONNECTIONS="50"           # Fewer but heavier connections
CUSTOM_DEFAULT_STATISTICS_TARGET="200" # Detailed statistics
```

## Verifying Performance Settings

After installation, verify the applied settings:

```bash
# Connect to PostgreSQL
sudo -u postgres psql

# Check specific parameters
SHOW shared_buffers;
SHOW effective_cache_size;
SHOW max_connections;
SHOW random_page_cost;

# Show all settings
SHOW ALL;

# Check current memory usage
SELECT 
    pg_size_pretty(pg_total_relation_size('pg_class')) as catalog_size,
    pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||tablename))::bigint) as tables_size
FROM pg_tables;

# Exit
\q
```

## Disabling Performance Tuning

To install with default PostgreSQL settings:

```bash
# In configs/install_config.conf
APPLY_PERFORMANCE_TUNING="no"
```

## Monitoring Performance

### Check Active Queries

```bash
sudo -u postgres psql -c "
SELECT 
    pid,
    now() - query_start as duration,
    state,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;"
```

### Check Database Size

```bash
sudo -u postgres psql -c "
SELECT 
    datname,
    pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;"
```

### Check Table Sizes

```bash
sudo -u postgres psql -d myappdb -c "
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;"
```

### Check Index Usage

```bash
sudo -u postgres psql -d myappdb -c "
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC
LIMIT 10;"
```

## Performance Tuning Best Practices

1. **Start with auto profile**: Let the script detect optimal settings
2. **Monitor query performance**: Use `EXPLAIN ANALYZE` for slow queries
3. **Create appropriate indexes**: Index columns used in WHERE clauses
4. **Regular VACUUM**: Keep statistics up-to-date
5. **Connection pooling**: Use pgBouncer for many concurrent connections
6. **Partition large tables**: Split tables with millions of rows
7. **Benchmark changes**: Test performance impact before production

## Troubleshooting Performance Issues

### Slow Queries

```sql
-- Enable query logging
ALTER SYSTEM SET log_min_duration_statement = 1000; -- Log queries > 1 second
SELECT pg_reload_conf();

-- Analyze slow query
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;
```

### High Memory Usage

```bash
# Check current settings
sudo -u postgres psql -c "SHOW shared_buffers;"
sudo -u postgres psql -c "SHOW max_connections;"

# Calculate total memory usage
# Formula: shared_buffers + (max_connections * work_mem) + maintenance_work_mem
```

### Checkpoint Too Frequent

```bash
# Check checkpoint frequency
sudo tail -f /var/log/postgresql/postgresql-*-main.log | grep checkpoint

# If too frequent, increase max_wal_size
# Edit /etc/postgresql/*/main/postgresql.conf
max_wal_size = 4GB
```

## Further Reading

- [PostgreSQL Performance Optimization](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [PostgreSQL Tuning Guide](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)
- [Configuration Reference](CONFIGURATION.md)
- [Back to Main README](../README.md)
