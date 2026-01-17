#!/bin/sh

ROOT_DIR=/usr/share/nginx/html

echo "Replacing environment variables in JS files..."

for file in $ROOT_DIR/assets/*.js $ROOT_DIR/*.js;
do
  if [ -f "$file" ]; then
    echo "Processing $file..."
    
    # Use a single replacement that catches all GraphQL URL patterns
    if [ -n "$VITE_APP_SERVER_GRAPHQL_URL" ]; then
      # Extract just the hostname+path from the URL for more flexible matching
      GRAPHQL_HOST=$(echo "$VITE_APP_SERVER_GRAPHQL_URL" | sed 's|https://||')
      
      # Replace ANY GraphQL URL pattern with our target URL
      sed -i -E "s|(http://|https://)?(localhost:5700|test-api\.boursenumeriquedafrique\.com)/graphql|$VITE_APP_SERVER_GRAPHQL_URL|g" "$file"
      
      # Also replace any standalone "gdh" strings
      sed -i "s|\"gdh\"|\"$VITE_APP_SERVER_GRAPHQL_URL\"|g" "$file"
      sed -i "s|'gdh'|'$VITE_APP_SERVER_GRAPHQL_URL'|g" "$file"
      sed -i "s|gdh|$VITE_APP_SERVER_GRAPHQL_URL|g" "$file"
    fi
    
    # Similar approach for WebSocket
    if [ -n "$VITE_SERVER_GRAPHQL_WS_URL" ]; then
      sed -i -E "s|(ws://|wss://)?(localhost:5700|test-api\.boursenumeriquedafrique\.com)/graphql/ws|$VITE_SERVER_GRAPHQL_WS_URL|g" "$file"
    fi
    
    # Payments URL
    sed -i "s|test-payments\.boursenumeriquedafrique\.com|payments.boursenumeriquedafrique.com|g" "$file"
  fi
done

echo "Environment variables replaced. Starting Nginx..."
exec "$@"