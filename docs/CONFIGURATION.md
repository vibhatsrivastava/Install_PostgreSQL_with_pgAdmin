# Configuration Reference

Complete reference for all configuration options across all installation scripts.

## Main Installation Configuration

File: `configs/install_config.conf`

### PostgreSQL Settings

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `POSTGRES_PASSWORD` | Postgres superuser password (min 8 chars) | String | ChangeMe123! |
| `POSTGRES_VERSION` | Specific PostgreSQL version to install | Version number or empty | (latest) |

### Custom Database User

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `CREATE_CUSTOM_USER` | Create a custom database user | yes, no | yes |
| `CUSTOM_USERNAME` | Username for custom user | String | dbuser |
| `CUSTOM_USER_PASSWORD` | Password for custom user | String | SecurePass456! |

### Custom Database

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `CREATE_CUSTOM_DATABASE` | Create a custom database | yes, no | yes |
| `CUSTOM_DATABASE_NAME` | Database name | String | myappdb |
| `CUSTOM_DATABASE_OWNER` | Database owner (must be existing user) | String | dbuser |

### Remote Access

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `ENABLE_REMOTE_ACCESS` | Allow remote connections | yes, no | no |
| `ALLOWED_IP_RANGE` | CIDR range for allowed IPs | CIDR notation | 0.0.0.0/0 |

### Performance Tuning

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `APPLY_PERFORMANCE_TUNING` | Enable performance optimization | yes, no | yes |
| `PERFORMANCE_PROFILE` | Performance profile | auto, low, medium, high, custom | auto |

#### Custom Performance Parameters

*Only used when `PERFORMANCE_PROFILE="custom"`*

| Option | Description | Example Value |
|--------|-------------|---------------|
| `CUSTOM_SHARED_BUFFERS` | PostgreSQL shared buffers | 2GB |
| `CUSTOM_EFFECTIVE_CACHE_SIZE` | Effective cache size | 6GB |
| `CUSTOM_MAINTENANCE_WORK_MEM` | Maintenance work memory | 512MB |
| `CUSTOM_WORK_MEM` | Work memory per operation | 16MB |
| `CUSTOM_MAX_CONNECTIONS` | Maximum connections | 150 |
| `CUSTOM_MAX_WAL_SIZE` | Maximum WAL size | 2GB |
| `CUSTOM_MIN_WAL_SIZE` | Minimum WAL size | 1GB |
| `CUSTOM_CHECKPOINT_COMPLETION_TARGET` | Checkpoint completion target | 0.9 |
| `CUSTOM_WAL_BUFFERS` | WAL buffers | 16MB |
| `CUSTOM_DEFAULT_STATISTICS_TARGET` | Statistics target | 100 |
| `CUSTOM_RANDOM_PAGE_COST` | Random page cost | 1.1 (SSD), 4.0 (HDD) |
| `CUSTOM_EFFECTIVE_IO_CONCURRENCY` | IO concurrency | 200 (SSD), 2 (HDD) |

### pgAdmin Settings

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `PGADMIN_EMAIL` | pgAdmin login email | Email address | admin@example.com |
| `PGADMIN_PASSWORD` | pgAdmin login password (min 6 chars) | String | Admin123! |

### Logging

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `LOG_FILE` | Installation log file path | File path | /var/log/postgresql_pgadmin_install_*.log |

## CDC Replication Configuration

File: `configs/install_cdc_config.conf`

### PostgreSQL Settings

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `POSTGRES_VERSION` | Target PostgreSQL version | Version number or empty | (auto-detect) |
| `POSTGRES_PASSWORD` | Superuser password | String | Admin@123 |

### Replication Configuration

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `SOURCE_DATABASE` | Source database name | String | ansible_execution_results |
| `TARGET_DATABASE` | Target database name | String | ansible_failed_jobs_vectordb |
| `SOURCE_TABLE` | Table to replicate | String | failed_jobs |
| `TEXT_COLUMN_TO_VECTORIZE` | Column for embeddings | String | message |
| `PUBLICATION_NAME` | Publication name | String | ansible_failed_jobs_pub |
| `SUBSCRIPTION_NAME` | Subscription name | String | ansible_failed_jobs_sub |

### Ollama Configuration

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `OLLAMA_API_URL` | Ollama API endpoint | URL | http://localhost:11434 |
| `OLLAMA_MODEL` | Embedding model | Model name | nomic-embed-text |
| `EMBEDDING_DIMENSION` | Vector dimensions | Integer | 768 |
| `LLM_MODEL` | LLM model (future use) | Model name | gpt-oss:20b |

### Feature Toggles

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `ENABLE_DDL_REPLICATION` | Auto DDL propagation | yes, no | yes |
| `ENABLE_EMBEDDING_GENERATION` | Auto embeddings | yes, no | yes |
| `ENABLE_PROMETHEUS_MONITORING` | Metrics export | yes, no | yes |

### Performance Settings

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `EMBEDDING_BATCH_SIZE` | Backfill batch size | Integer | 100 |
| `EMBEDDING_THROTTLE_SECONDS` | Delay between batches | Integer | 1 |
| `MAX_TEXT_LENGTH` | Max text chars | Integer | 8000 |
| `DDL_POLL_INTERVAL_SECONDS` | DDL check interval | Integer | 30 |

## Apache Reverse Proxy Configuration

File: `configs/install_config_proxy.conf`

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `DOMAIN_NAME` | Local domain name | Domain string | postgresql.local |
| `ENABLE_SSL` | Enable HTTPS with self-signed cert | yes, no | yes |
| `SSL_COUNTRY` | Certificate country code | 2-letter code | US |
| `SSL_STATE` | Certificate state/province | String | California |
| `SSL_CITY` | Certificate city | String | San Francisco |
| `SSL_ORG` | Certificate organization | String | Development |
| `SSL_DAYS_VALID` | Certificate validity in days | Integer | 365 |
| `APACHE_CONFIG_NAME` | VirtualHost config file name | String | pgadmin-proxy |
| `HTTP_PORT` | HTTP port | Port number | 80 |
| `HTTPS_PORT` | HTTPS port | Port number | 443 |

## pgAdmin Upgrade Configuration

File: `configs/upgrade_pgadmin_config.conf`

| Option | Description | Valid Values | Default |
|--------|-------------|--------------|---------|
| `TARGET_VERSION` | Target pgAdmin version | latest or version number | latest |
| `DRY_RUN` | Test without making changes | yes, no | no |
| `BACKUP_DIR` | Backup directory path | Directory path | /tmp/pgadmin_backup_* |
| `KEEP_BACKUP` | Keep backup after successful upgrade | yes, no | yes |

## Configuration Best Practices

### Security

1. **Change default passwords** before running any installation
2. **Secure configuration files**: 
   ```bash
   chmod 600 configs/*.conf
   ```
3. **Restrict remote access** using specific IP ranges instead of `0.0.0.0/0`
4. **Use strong passwords**: 
   - PostgreSQL: Minimum 12 characters, mix of letters, numbers, symbols
   - pgAdmin: Minimum 8 characters

### Performance

1. **Start with `auto` profile** and tune later based on monitoring
2. **Match `max_connections` to actual usage** to avoid memory waste
3. **Adjust `work_mem` carefully** - high values * many connections = OOM
4. **Monitor and iterate** using performance metrics

### Maintenance

1. **Document customizations** in separate notes file
2. **Version control configurations** (exclude passwords)
3. **Test configuration changes** in development first
4. **Keep backups** of working configurations

## Environment-Specific Configurations

### Development Environment

```bash
# configs/install_config.conf
ENABLE_REMOTE_ACCESS="no"
APPLY_PERFORMANCE_TUNING="yes"
PERFORMANCE_PROFILE="low"
CREATE_CUSTOM_USER="yes"
CREATE_CUSTOM_DATABASE="yes"
```

### Production Environment

```bash
# configs/install_config.conf
ENABLE_REMOTE_ACCESS="yes"
ALLOWED_IP_RANGE="10.0.0.0/24"  # Specific network only
APPLY_PERFORMANCE_TUNING="yes"
PERFORMANCE_PROFILE="high"
CREATE_CUSTOM_USER="yes"
CREATE_CUSTOM_DATABASE="yes"

# Use strong, unique passwords
POSTGRES_PASSWORD="<generate-strong-password>"
PGADMIN_PASSWORD="<generate-strong-password>"
CUSTOM_USER_PASSWORD="<generate-strong-password>"
```

### Testing Environment

```bash
# configs/install_config.conf
ENABLE_REMOTE_ACCESS="yes"
ALLOWED_IP_RANGE="0.0.0.0/0"  # Allow from anywhere for testing
APPLY_PERFORMANCE_TUNING="yes"
PERFORMANCE_PROFILE="medium"
```

## Validation

All configuration files are validated during script execution. Common validation checks include:

- **Password length**: PostgreSQL (8 chars), pgAdmin (6 chars)
- **Boolean values**: Must be exactly "yes" or "no" (not true/false)
- **File paths**: Checked for existence and permissions
- **Network ranges**: Validated CIDR notation
- **Port numbers**: Checked for valid range and availability

---

**Related Documentation:**
- [Performance Tuning Guide](PERFORMANCE_TUNING.md)
- [CDC Replication Guide](CDC_REPLICATION.md)
- [Apache Proxy Setup](APACHE_PROXY.md)
- [Back to Main README](../README.md)
