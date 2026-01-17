#!/bin/sh
set -e

echo "=== Frontend Entrypoint Script Started ==="
echo "Environment variables:"
echo "VITE_APP_SERVER_GRAPHQL_URL=${VITE_APP_SERVER_GRAPHQL_URL}"
echo "VITE_SERVER_GRAPHQL_WS_URL=${VITE_SERVER_GRAPHQL_WS_URL}"

CONFIG_FILE=/usr/share/nginx/html/config.js

if [ -f "$CONFIG_FILE" ]; then
  echo "✓ Found config.js at $CONFIG_FILE"
  
  echo "Before replacement:"
  cat "$CONFIG_FILE"
  
  # Do the replacements
  if [ -n "$VITE_APP_SERVER_GRAPHQL_URL" ]; then
    sed -i "s|__GRAPHQL_URL__|${VITE_APP_SERVER_GRAPHQL_URL}|g" "$CONFIG_FILE"
    echo "✓ Replaced GRAPHQL_URL"
  else
    echo "⚠️  VITE_APP_SERVER_GRAPHQL_URL is empty!"
  fi
  
  if [ -n "$VITE_SERVER_GRAPHQL_WS_URL" ]; then
    sed -i "s|__WS_URL__|${VITE_SERVER_GRAPHQL_WS_URL}|g" "$CONFIG_FILE"
    echo "✓ Replaced WS_URL"
  else
    echo "⚠️  VITE_SERVER_GRAPHQL_WS_URL is empty!"
  fi
  
  echo ""
  echo "After replacement:"
  cat "$CONFIG_FILE"
else
  echo "✗ config.js NOT found at $CONFIG_FILE"
  echo "Listing directory:"
  ls -la /usr/share/nginx/html/ | head -20
fi

echo "=== Starting Nginx ==="
exec "$@"