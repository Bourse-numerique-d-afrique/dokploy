#!/bin/sh

# This script replaces environment variable placeholders in the built JS files at container startup.
# This allows the same Docker image to be used across different environments (staging, production).

ROOT_DIR=/usr/share/nginx/html

echo "Replacing environment variables in JS files..."

# Find all JS files in the assets directory
for file in $ROOT_DIR/assets/*.js;
do
  if [ -f "$file" ]; then
    echo "Processing $file..."
    
    # Replace the GraphQL HTTP URL if the environment variable is set
    # VITE_APP_SERVER_GRAPHQL_URL=https://api.boursenumeriquedafrique.com/graphql
    if [ -n "$VITE_APP_SERVER_GRAPHQL_URL" ]; then
      # 1. Exact match with /graphql (Safest)
      sed -i "s|http://localhost:5700/graphql|$VITE_APP_SERVER_GRAPHQL_URL|g" "$file"
      sed -i "s|http://test-api.boursenumeriquedafrique.com/graphql|$VITE_APP_SERVER_GRAPHQL_URL|g" "$file"
    fi
    
    # Replace the GraphQL WebSocket URL
    # VITE_SERVER_GRAPHQL_WS_URL=wss://api.boursenumeriquedafrique.com/graphql/ws
    if [ -n "$VITE_SERVER_GRAPHQL_WS_URL" ]; then
      sed -i "s|ws://localhost:5700/graphql/ws|$VITE_SERVER_GRAPHQL_WS_URL|g" "$file"
      sed -i "s|ws://test-api.boursenumeriquedafrique.com/graphql/ws|$VITE_SERVER_GRAPHQL_WS_URL|g" "$file"
    fi

     # Replace Payments URL
     sed -i "s|test-payments.boursenumeriquedafrique.com|payments.boursenumeriquedafrique.com|g" "$file"
  fi
done

echo "Environment variables replaced. Starting Nginx..."
exec "$@"
