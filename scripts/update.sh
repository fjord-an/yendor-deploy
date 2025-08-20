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
