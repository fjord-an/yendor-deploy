#!/bin/bash
#
# Copyright (c) 2025 PaceySpace
# 
# This file is part of the YendorCats.com website framework.
# 
# The technical implementation, architecture, and code contained in this file
# are the exclusive intellectual property of PaceySpace and
# may be used as a template for future client projects.
# 
# Licensed under the Apache License, Version 2.0.
# See LICENSE file for full terms and conditions.
#
# Client: Yendor Cat Breeding Enterprise
# Project: YendorCats.com Website
# Developer: PaceySpace
#


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
