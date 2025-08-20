#!/bin/bash

# YendorCats Backup Script
set -e

BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="yendorcats_backup_${DATE}"

echo "💾 Starting backup process..."

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup application data
echo "📦 Backing up application data..."
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}_data.tar.gz" -C /home/ubuntu/yendorcats.com data logs

# Backup configuration
echo "📋 Backing up configuration..."
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}_config.tar.gz" -C /home/ubuntu/yendorcats.com docker-compose.yml nginx scripts

# Export container configurations
echo "🐳 Exporting container configurations..."
docker-compose config > "${BACKUP_DIR}/${BACKUP_NAME}_compose.yml"

# List backups
echo "📁 Available backups:"
ls -la $BACKUP_DIR/

echo "✅ Backup completed: ${BACKUP_NAME}"
