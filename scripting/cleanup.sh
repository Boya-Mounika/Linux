#!/bin/bash

# ======================================================
# GitLab Runner Cleanup Script
# Server: Dev-VM
# Purpose: Clean Podman images, containers, and runner cache safely
# ======================================================

LOGFILE="/var/log/gitlab-runner-cleanup.log"
LOCKFILE="/var/run/gitlab-runner-cleanup.lock"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Prevent multiple executions
exec 9>$LOCKFILE
flock -n 9 || exit 0

echo "======================================" >> $LOGFILE
echo "Cleanup started at $DATE" >> $LOGFILE

# Always restart runner if script exits unexpectedly
cleanup_finish() {
    echo "Starting GitLab Runner..." >> $LOGFILE
    systemctl start gitlab-runner >> $LOGFILE 2>&1
    echo "Cleanup completed at $(date '+%Y-%m-%d %H:%M:%S')" >> $LOGFILE
    echo "======================================" >> $LOGFILE
}
trap cleanup_finish EXIT

# Stop runner safely
echo "Stopping GitLab Runner..." >> $LOGFILE
systemctl stop gitlab-runner >> $LOGFILE 2>&1

sleep 10

# Ensure correct working directory
cd /home/gitlab-runner || exit 1

# Fix podman state if needed
echo "Running podman system migrate..." >> $LOGFILE
sudo -u gitlab-runner podman system migrate >> $LOGFILE 2>&1

# Clean unused containers
echo "Cleaning unused containers..." >> $LOGFILE
sudo -u gitlab-runner podman container prune -f >> $LOGFILE 2>&1

# Clean unused images
echo "Cleaning unused images..." >> $LOGFILE
sudo -u gitlab-runner podman image prune -a -f >> $LOGFILE 2>&1

# Clean unused volumes
echo "Cleaning unused volumes..." >> $LOGFILE
sudo -u gitlab-runner podman volume prune -f >> $LOGFILE 2>&1

# Clean builds older than 7 days
echo "Cleaning builds older than 7 days..." >> $LOGFILE
find /home/gitlab-runner/builds -mindepth 1 -mtime +7 -exec rm -rf {} + >> $LOGFILE 2>&1

# Clean cache older than 7 days
echo "Cleaning cache older than 7 days..." >> $LOGFILE
find /home/gitlab-runner/cache -mindepth 1 -mtime +7 -exec rm -rf {} + >> $LOGFILE 2>&1

# Clean temporary files
echo "Cleaning temporary files..." >> $LOGFILE
find /home/gitlab-runner -name "*.tmp" -type f -mtime +3 -delete >> $LOGFILE 2>&1

# Clean podman temp storage safely
echo "Cleaning podman temp files..." >> $LOGFILE
find /home/gitlab-runner/.local/share/containers/storage/tmp -type f -mtime +3 -delete >> $LOGFILE 2>&1

exit 0

