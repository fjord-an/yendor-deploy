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

# YendorCats Deployment Script
set -e

echo "🚀 Starting YendorCats deployment..."

# Login to ECR
echo "📥 Logging into ECR..."
/usr/local/bin/ecr-login.sh

# Pull latest images
echo "🔄 Pulling latest images..."
docker-compose pull

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Start new containers
echo "▶️  Starting new containers..."
docker-compose up -d

# Show running containers
echo "📊 Container status:"
docker-compose ps

# Show logs
echo "📋 Recent logs:"
docker-compose logs --tail=10

echo "✅ Deployment completed successfully!"
