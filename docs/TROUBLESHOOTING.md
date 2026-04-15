# Troubleshooting Guide

Common issues and solutions for PostgreSQL, pgAdmin, CDC replication, and related components.

## Installation Issues

### Script Fails with Permission Denied

**Symptom:** Installation script cannot be executed

```bash
bash: ./install_postgresql_pgadmin.sh: Permission denied
```

**Solution:**
```bash
chmod +x install_postgresql_pgadmin.sh
sudo ./install_postgresql_pgadmin.sh
```

### Configuration File Not Found

**Symptom:** Script reports configuration file missing

**Solution:**
```bash
# Ensure config file exists in configs/ directory
ls -la configs/install_config.conf

# If missing, copy from example
cp configs/install_config.conf.example configs/install_config.conf
nano configs/install_config.conf
```

### Installation Hangs or Freezes

**Symptom:** Installation stops responding

**Solution:**
1. Check system resources:
   ```bash
   free -h
   df -h
   top
   ```
2. Check for dpkg locks:
   ```bash
   sudo lsof /var/lib/dpkg/lock-frontend
   sudo rm /var/lib/dpkg/lock-frontend
   sudo dpkg --configure -a
   ```
3. Restart installation

### Rollback Fails

**Symptom:** Automatic rollback encounters errors

**Solution:**
```bash
# Use cleanup script
sudo ./cleanup_stuck_installation.sh

# Or manual cleanup
sudo systemctl stop postgresql apache2
sudo apt remove --purge postgresql* pgadmin*
sudo rm -rf /etc/postgresql /var/lib/postgresql
```

## PostgreSQL Issues

### Cannot Connect to PostgreSQL

**Symptom:** Connection refused or authentication failed

**Check service status:**
```bash
sudo systemctl status postgresql
```

**Check if PostgreSQL is listening:**
```bash
sudo netstat -plnt | grep 5432
```

**Solution:**
1. Start PostgreSQL if stopped:
   ```bash
   sudo systemctl start postgresql
   ```
2. Check pg_hba.conf authentication rules:
   ```bash
   sudo nano /etc/postgresql/*/main/pg_hba.conf
   ```
3. Reload configuration:
   ```bash
   sudo systemctl reload postgresql
   ```

### Remote Connections Not Working

**Symptom:** Cannot connect from remote machines

**Check configuration:**
```bash
# Check listen_addresses
sudo -u postgres psql -c "SHOW listen_addresses;"

# Check pg_hba.conf
sudo cat /etc/postgresql/*/main/pg_hba.conf | grep -v "^#"
```

**Solution:**
1. Edit postgresql.conf:
   ```bash
   sudo nano /etc/postgresql/*/main/postgresql.conf
   # Ensure: listen_addresses = '*'
   ```
2. Edit pg_hba.conf:
   ```bash
   sudo nano /etc/postgresql/*/main/pg_hba.conf
   # Add: host all all 0.0.0.0/0 md5
   ```
3. Restart PostgreSQL:
   ```bash
   sudo systemctl restart postgresql
   ```
4. Check firewall:
   ```bash
   sudo ufw allow 5432/tcp
   ```

### Out of Memory Errors

**Symptom:** PostgreSQL crashes or refuses connections

```
FATAL: could not fork new process for connection: Cannot allocate memory
```

**Solution:**
1. Check current settings:
   ```bash
   sudo -u postgres psql -c "SHOW shared_buffers;"
   sudo -u postgres psql -c "SHOW max_connections;"
   ```
2. Reduce memory usage:
   ```bash
   # Edit configs/install_config.conf
   PERFORMANCE_PROFILE="low"
   CUSTOM_MAX_CONNECTIONS="50"
   CUSTOM_SHARED_BUFFERS="256MB"
   ```
3. Restart and reapply configuration

### High CPU Usage

**Symptom:** PostgreSQL consuming excessive CPU

**Identify problem queries:**
```bash
sudo -u postgres psql -c "
SELECT pid, query_start, state, query 
FROM pg_stat_activity 
WHERE state != 'idle' 
ORDER BY query_start;"
```

**Solution:**
1. Kill problematic query:
   ```bash
   sudo -u postgres psql -c "SELECT pg_terminate_backend(PID);"
   ```
2. Optimize slow queries (add indexes, rewrite queries)
3. Run VACUUM ANALYZE:
   ```bash
   sudo -u postgres psql -d myappdb -c "VACUUM ANALYZE;"
   ```

## pgAdmin Issues

### Cannot Access pgAdmin Web Interface

**Symptom:** Browser shows "Unable to connect" or 404 error

**Check Apache status:**
```bash
sudo systemctl status apache2
```

**Check pgAdmin configuration:**
```bash
ls -la /usr/pgadmin4/
curl -I http://localhost/pgadmin4/
```

**Solution:**
1. Restart Apache:
   ```bash
   sudo systemctl restart apache2
   ```
2. Check Apache logs:
   ```bash
   sudo tail -50 /var/log/apache2/error.log
   ```
3. Reinstall pgAdmin if necessary

### pgAdmin Login Fails

**Symptom:** Incorrect credentials or login page not loading

**Solution:**
1. Reset pgAdmin:
   ```bash
   sudo /usr/pgadmin4/bin/setup-web.sh
   ```
2. Enter new email and password when prompted

### Cannot Add PostgreSQL Server in pgAdmin

**Symptom:** Connection fails when adding server

**Check connection details:**
- Host: localhost (for local) or IP address
- Port: 5432
- Username: postgres or custom user
- Password: configured password

**Solution:**
1. Test connection from command line:
   ```bash
   psql -U postgres -h localhost -c "SELECT 1;"
   ```
2. Check PostgreSQL authentication:
   ```bash
   sudo nano /etc/postgresql/*/main/pg_hba.conf
   # Ensure: local all all md5
   ```
3. Restart PostgreSQL:
   ```bash
   sudo systemctl restart postgresql
   ```

## CDC Replication Issues

### Replication Not Starting

**Symptom:** Subscription created but no data replicates

**Check publication:**
```bash
sudo -u postgres psql -d source_db -c "SELECT * FROM pg_publication;"
```

**Check subscription:**
```bash
sudo -u postgres psql -d target_db -c "SELECT * FROM pg_subscription;"
```

**Check replication slot:**
```bash
sudo -u postgres psql -c "SELECT * FROM pg_replication_slots;"
```

**Solution:**
1. Ensure `wal_level = logical`:
   ```bash
   sudo -u postgres psql -c "SHOW wal_level;"
   # If not 'logical', edit postgresql.conf and restart
   ```
2. Check PostgreSQL logs:
   ```bash
   sudo tail -100 /var/log/postgresql/postgresql-*-main.log
   ```
3. Restart subscription:
   ```bash
   sudo -u postgres psql -d target_db -c "ALTER SUBSCRIPTION sub_name DISABLE;"
   sudo -u postgres psql -d target_db -c "ALTER SUBSCRIPTION sub_name ENABLE;"
   ```

### Embeddings Not Generating

**Symptom:** Vector column is NULL for new rows

**Test Ollama connection:**
```bash
curl http://localhost:11434/api/tags
```

**Test embedding function:**
```bash
sudo -u postgres psql -d target_db -c "SELECT generate_embedding('test');"
```

**Solution:**
1. Verify Ollama is running:
   ```bash
   systemctl status ollama
   # or for Docker
   docker ps | grep ollama
   ```
2. Check model is available:
   ```bash
   ollama list
   ```
3. Verify plpython3u extension:
   ```bash
   sudo -u postgres psql -d target_db -c "SELECT * FROM pg_extension WHERE extname = 'plpython3u';"
   ```
4. Check trigger exists:
   ```bash
   sudo -u postgres psql -d target_db -c "\d+ table_name"
   ```

### DDL Changes Not Propagating

**Symptom:** Schema changes don't replicate to target

**Check DDL worker:**
```bash
sudo systemctl status ddl-replication-worker
```

**Check DDL logs:**
```bash
sudo tail -50 /var/log/ddl_replication.log
```

**Check event trigger:**
```bash
sudo -u postgres psql -d source_db -c "SELECT * FROM pg_event_trigger;"
```

**Solution:**
1. Restart DDL worker:
   ```bash
   sudo systemctl restart ddl-replication-worker
   ```
2. Check Python dependencies:
   ```bash
   pip3 list | grep psycopg2
   ```
3. Manual DDL replication:
   ```bash
   # Execute DDL on target database manually
   sudo -u postgres psql -d target_db -c "ALTER TABLE ..."
   ```

### High Replication Lag

**Symptom:** Target database significantly behind source

**Check lag:**
```bash
sudo -u postgres psql -d target_db -c "
SELECT 
    subname,
    now() - last_msg_send_time as lag 
FROM pg_stat_subscription;"
```

**Solution:**
1. Increase `max_wal_senders`:
   ```bash
   sudo nano /etc/postgresql/*/main/postgresql.conf
   # max_wal_senders = 10
   sudo systemctl restart postgresql
   ```
2. Optimize embedding generation:
   ```bash
   # In configs/install_cdc_config.conf
   EMBEDDING_THROTTLE_SECONDS="2"  # Increase delay
   EMBEDDING_BATCH_SIZE="50"        # Smaller batches
   ```
3. Check network latency to Ollama
4. Check for long-running transactions:
   ```bash
   sudo -u postgres psql -c "SELECT * FROM pg_stat_activity WHERE state != 'idle';"
   ```

## Apache Reverse Proxy Issues

### Domain Not Resolving

**Symptom:** Browser cannot find custom domain

**Check /etc/hosts:**
```bash
cat /etc/hosts | grep postgresql.local
```

**Solution:**
```bash
echo "127.0.0.1    postgresql.local" | sudo tee -a /etc/hosts
```

### SSL Certificate Warnings

**Symptom:** Browser shows security warning

**Solution:**
This is normal for self-signed certificates. Click "Advanced" and "Proceed" in your browser.

For permanent trust:
```bash
sudo cp /etc/apache2/ssl/postgresql.local/postgresql.local.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### HTTP 503 or 502 Errors

**Symptom:** Proxy returns error codes

**Check pgAdmin is running:**
```bash
curl -I http://localhost/pgadmin4/
```

**Check Apache error logs:**
```bash
sudo tail -50 /var/log/apache2/pgadmin-proxy_error.log
```

**Solution:**
1. Restart Apache:
   ```bash
   sudo systemctl restart apache2
   ```
2. Check proxy modules:
   ```bash
   apache2ctl -M | grep proxy
   ```
3. Check VirtualHost configuration:
   ```bash
   sudo apache2ctl -t
   ```

## Performance Issues

### Slow Queries

**Identify slow queries:**
```bash
sudo -u postgres psql -c "
SELECT pid, now() - query_start as duration, query 
FROM pg_stat_activity 
WHERE state != 'idle' 
ORDER BY duration DESC;"
```

**Analyze query:**
```sql
EXPLAIN ANALYZE SELECT ...;
```

**Solution:**
1. Add appropriate indexes
2. Increase work_mem for complex queries
3. Run VACUUM ANALYZE
4. Optimize query logic

### Database Growing Too Large

**Check sizes:**
```bash
sudo -u postgres psql -c "
SELECT 
    datname,
    pg_size_pretty(pg_database_size(datname)) 
FROM pg_database 
ORDER BY pg_database_size(datname) DESC;"
```

**Solution:**
1. Run VACUUM FULL:
   ```bash
   sudo -u postgres psql -d myappdb -c "VACUUM FULL;"
   ```
2. Implement table partitioning
3. Set up automated cleanup jobs
4. Archive old data

### Connection Pool Exhausted

**Symptom:** Too many connections

```
FATAL: sorry, too many clients already
```

**Check connections:**
```bash
sudo -u postgres psql -c "
SELECT count(*), usename FROM pg_stat_activity 
GROUP BY usename;"
```

**Solution:**
1. Increase max_connections:
   ```bash
   # In configs/install_config.conf
   CUSTOM_MAX_CONNECTIONS="200"
   ```
2. Implement connection pooling (pgBouncer)
3. Close idle connections:
   ```bash
   sudo -u postgres psql -c "
   SELECT pg_terminate_backend(pid) 
   FROM pg_stat_activity 
   WHERE state = 'idle' AND state_change < now() - interval '1 hour';"
   ```

## Getting Help

### Collect Diagnostic Information

```bash
# System info
uname -a
free -h
df -h

# PostgreSQL version
sudo -u postgres psql -c "SELECT version();"

# Service status
sudo systemctl status postgresql apache2

# Recent logs
sudo tail -100 /var/log/postgresql/postgresql-*-main.log
sudo tail -100 /var/log/apache2/error.log

# Configuration
sudo -u postgres psql -c "SHOW ALL;"
```

### Log Files Locations

- **PostgreSQL**: `/var/log/postgresql/postgresql-*-main.log`
- **Apache**: `/var/log/apache2/error.log`
- **Installation**: `/var/log/postgresql_pgadmin_install_*.log`
- **CDC DDL Worker**: `/var/log/ddl_replication.log`
- **pgAdmin**: `/var/log/pgadmin/`

### Support Resources

- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **pgAdmin Documentation**: https://www.pgadmin.org/docs/
- **Ubuntu Community**: https://askubuntu.com/
- **Project Issues**: GitHub repository issues page

---

**Related Documentation:**
- [Configuration Reference](CONFIGURATION.md)
- [Command Reference](COMMANDS.md)
- [Performance Tuning Guide](PERFORMANCE_TUNING.md)
- [Back to Main README](../README.md)
