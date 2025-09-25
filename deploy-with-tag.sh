#!/bin/bash


# Set AWS region default
export AWS_DEFAULT_REGION=ap-southeast-2
# Deploy script that uses a specific git commit hash or tag for Docker images

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Check if IMAGE_TAG is provided as argument or environment variable
if [ -n "$1" ]; then
    export IMAGE_TAG="$1"
elif [ -z "$IMAGE_TAG" ]; then
    print_message "Error: No IMAGE_TAG specified!" "$RED"
    echo "Usage: $0 <image-tag>"
    echo "   or: IMAGE_TAG=<tag> $0"
    echo ""
    echo "Example: $0 74cde28"
    echo "     or: IMAGE_TAG=74cde28 $0"
    exit 1
fi

print_message "Deploying with IMAGE_TAG: $IMAGE_TAG" "$GREEN"

# Update the docker-compose file
./update-compose-tag.sh "$IMAGE_TAG"

# Pull the new images
print_message "Pulling images with tag: $IMAGE_TAG" "$YELLOW"
docker-compose -f docker-compose.production.yml pull --policy always

# Stop and remove old containers
print_message "Stopping old containers..." "$YELLOW"
docker-compose -f docker-compose.production.yml down

# Start new containers
print_message "Starting new containers..." "$YELLOW"
docker-compose -f docker-compose.production.yml up -d

# Show status
print_message "Deployment complete! Container status:" "$GREEN"
docker-compose -f docker-compose.production.yml ps

# Show the images being used
echo ""
print_message "Images in use:" "$GREEN"
docker-compose -f docker-compose.production.yml images
