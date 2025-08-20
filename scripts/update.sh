#!/bin/bash

# YendorCats Update Script (zero-downtime)
set -e

echo "🔄 Starting zero-downtime update..."

# Login to ECR
/usr/local/bin/ecr-login.sh

# Pull latest images
echo "📥 Pulling latest images..."
docker-compose pull

# Recreate containers with new images
echo "🔄 Updating containers..."
docker-compose up -d --force-recreate

# Clean up old images
echo "🧹 Cleaning up old images..."
docker image prune -f

echo "✅ Update completed successfully!"
