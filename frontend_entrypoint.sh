#!/bin/sh
set -e

: "${VITE_APP_SERVER_GRAPHQL_URL:?Missing VITE_APP_SERVER_GRAPHQL_URL}"
: "${VITE_SERVER_GRAPHQL_WS_URL:?Missing VITE_SERVER_GRAPHQL_WS_URL}"

cat <<EOF > /usr/share/nginx/html/env.js
window.__ENV__ = {
  GRAPHQL_HTTP: "${VITE_APP_SERVER_GRAPHQL_URL}",
  GRAPHQL_WS: "${VITE_SERVER_GRAPHQL_WS_URL}"
};
EOF

exec nginx -g "daemon off;"
