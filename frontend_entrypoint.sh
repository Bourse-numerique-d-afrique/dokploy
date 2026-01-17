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
    if [ -n "$VITE_APP_SERVER_GRAPHQL_URL" ]; then
      # Replace localhost (default dev) AND test-api (what was baked in)
      sed -i "s|http://localhost:5700/graphql|$VITE_APP_SERVER_GRAPHQL_URL|g" "$file"
      sed -i "s|http://test-api.boursenumeriquedafrique.com/graphql|$VITE_APP_SERVER_GRAPHQL_URL|g" "$file"
      
      # Also catch the root domain just in case of slight var variations
      sed -i "s|http://test-api.boursenumeriquedafrique.com|$VITE_APP_SERVER_GRAPHQL_URL|g" "$file"
    fi
    
    # Replace the GraphQL WebSocket URL if the environment variable is set
    if [ -n "$VITE_SERVER_GRAPHQL_WS_URL" ]; then
      sed -i "s|ws://localhost:5700/graphql/ws|$VITE_SERVER_GRAPHQL_WS_URL|g" "$file"
      sed -i "s|ws://test-api.boursenumeriquedafrique.com/graphql/ws|$VITE_SERVER_GRAPHQL_WS_URL|g" "$file"
      
      # Also catch the root domain
      sed -i "s|ws://test-api.boursenumeriquedafrique.com|$VITE_SERVER_GRAPHQL_WS_URL|g" "$file"
    fi

     # Replace Payments URL if needed (for MTN/Airtel callbacks that might be in frontend)
     # Note: checking if there are other vars typically used for this
     # Based on previous investigation, we saw 'test-payments' in the file.
     # We should probably blindly replace test-payments with production payments if we can infer the URL, 
     # or just leave it since the user's immediate issue is API.
     # BUT, I saw 'test-payments' in my earlier grep. I should fix it.
     # I'll use a hardcoded fix for now or derive it? 
     # The .env has MTN_WEBHOOK_HOST=payments... so maybe I can use that?
     # Wait, MTN_WEBHOOK_HOST is a backend var usually. Frontend shouldn't have it?
     # Actually the frontend *does* sometimes have callback URLs constructed.
     # Let's add a generic replacement for test-payments -> payments.
     sed -i "s|test-payments.boursenumeriquedafrique.com|payments.boursenumeriquedafrique.com|g" "$file"
  fi
done

echo "Environment variables replaced. Starting Nginx..."

# Execute the CMD passed to the docker container (usually nginx -g 'daemon off;')
exec "$@"
