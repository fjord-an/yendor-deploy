#!/bin/bash

# Script to update docker-compose.production.yml with a specific git commit hash tag

if [ -z "$1" ]; then
    echo "Usage: $0 <commit-hash>"
    echo "Example: $0 74cde28"
    echo "Special: $0 latest (resets to latest tags)"
    exit 1
fi

COMMIT_HASH=$1
COMPOSE_FILE="docker-compose.production.yml"

# Check if the compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: $COMPOSE_FILE not found!"
    exit 1
fi

# Create a backup of the original file
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

if [ "$COMMIT_HASH" = "latest" ]; then
    # Reset all tags to :latest
    echo "Resetting image tags to :latest..."
    sed -i 's|yendorcats-api:[^[:space:]]*|yendorcats-api:latest|g' "$COMPOSE_FILE"
    sed -i 's|yendorcats-uploader:[^[:space:]]*|yendorcats-uploader:latest|g' "$COMPOSE_FILE"
    sed -i 's|yendorcats-frontend:[^[:space:]]*|yendorcats-frontend:latest|g' "$COMPOSE_FILE"
else
    # Update the image tags from current tags to the commit hash
    sed -i "s|yendorcats-api:[^[:space:]]*|yendorcats-api:${COMMIT_HASH}|g" "$COMPOSE_FILE"
    sed -i "s|yendorcats-uploader:[^[:space:]]*|yendorcats-uploader:${COMMIT_HASH}|g" "$COMPOSE_FILE"
    sed -i "s|yendorcats-frontend:[^[:space:]]*|yendorcats-frontend:${COMMIT_HASH}|g" "$COMPOSE_FILE"
fi

echo "Updated $COMPOSE_FILE with tag: $COMMIT_HASH"
echo "Backup created as ${COMPOSE_FILE}.backup.*"
echo ""
echo "Updated image references:"
grep -E "image:.*yendorcats-(api|uploader|frontend)" "$COMPOSE_FILE"
