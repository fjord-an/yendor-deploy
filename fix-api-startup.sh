#!/bin/sh
# Remove wwwroot folder if it exists (API shouldn't serve frontend files)
if [ -d "/app/wwwroot" ]; then
    echo "Removing wwwroot folder from API container..."
    rm -rf /app/wwwroot
fi

# Start the original entrypoint
exec /app/entrypoint.sh
