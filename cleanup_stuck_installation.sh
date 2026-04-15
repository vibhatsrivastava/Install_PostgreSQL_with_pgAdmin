#!/bin/bash

###############################################################################
# Cleanup Script for Stuck CDC Installation
###############################################################################

echo "=== Cleaning up stuck CDC installation ==="

# Kill any hung installation processes
echo "Step 1: Killing stuck processes..."
pkill -9 -f "install_cdc_replication.sh" 2>/dev/null
sleep 2

# Terminate long-running/idle transactions in source database
echo "Step 2: Terminating blocking transactions..."
sudo -u postgres psql -d ansible_execution_results -c "
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = 'ansible_execution_results' 
  AND pid != pg_backend_pid() 
  AND state IN ('idle in transaction', 'idle in transaction (aborted)')
  AND NOW() - state_change > interval '1 minute';"

# Drop any partially created replication slot
echo "Step 3: Cleaning up replication slots..."
sudo -u postgres psql -d ansible_execution_results -c "
SELECT pg_drop_replication_slot(slot_name) 
FROM pg_replication_slots 
WHERE slot_name = 'ansible_failed_jobs_sub';" 2>/dev/null || true

# Also try terminating any active slot connections
sudo -u postgres psql -c "
SELECT pg_terminate_backend(active_pid) 
FROM pg_replication_slots 
WHERE slot_name = 'ansible_failed_jobs_sub' 
  AND active_pid IS NOT NULL;" 2>/dev/null || true

# Drop subscription if exists
echo "Step 4: Cleaning up subscription..."
sudo -u postgres psql -d ansible_failed_jobs_vectordb -c "
DROP SUBSCRIPTION IF EXISTS ansible_failed_jobs_sub;" 2>/dev/null || true

# Drop publication
echo "Step 5: Cleaning up publication..."
sudo -u postgres psql -d ansible_execution_results -c "
DROP PUBLICATION IF EXISTS ansible_failed_jobs_pub;" 2>/dev/null || true

# Drop target database
echo "Step 6: Dropping target database..."
sudo -u postgres psql -c "
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = 'ansible_failed_jobs_vectordb' 
  AND pid != pg_backend_pid();" > /dev/null 2>&1 || true

sudo -u postgres psql -c "
DROP DATABASE IF EXISTS ansible_failed_jobs_vectordb;" 2>/dev/null || true

echo ""
echo "=== Cleanup complete! ==="
echo ""
echo "Now you can re-run the installation:"
echo "  sudo ./install_cdc_replication.sh"
echo ""
