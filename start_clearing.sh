#!/bin/bash
set -e

# Install socat if missing
if ! command -v socat &> /dev/null; then
    echo "Installing socat..."
    apt-get update && apt-get install -y socat
fi

echo "Starting socat port forwarders (offset ports)..."
# Forward 8501 -> 8500
socat TCP-LISTEN:8501,fork,bind=0.0.0.0,reuseaddr TCP:127.0.0.1:8500 &
# Forward 5715 -> 5705
socat TCP-LISTEN:5715,fork,bind=0.0.0.0,reuseaddr TCP:127.0.0.1:5705 &
# Forward 5716 -> 5706
socat TCP-LISTEN:5716,fork,bind=0.0.0.0,reuseaddr TCP:127.0.0.1:5706 &

echo "Starting Clearing House in foreground..."
exec /usr/local/bin/clearing_house
