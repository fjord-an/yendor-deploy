#!/bin/bash

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
