#!/bin/bash

# Simple test server script for portpeek testing
# Usage: ./test_server.sh <port>
# Starts a Python HTTP server on the given port

port="$1"

if [ -z "$port" ]; then
  echo "Usage: $0 <port_number>"
  exit 1
fi

if ! [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]; then
  echo "Invalid port: Must be number 1-65535"
  exit 1
fi

echo "Starting test server on port $port..."
python3 -m http.server "$port" &

echo "Server started in background (PID: $!). Test with: ./portpeek.sh $port"
echo "Stop with: kill $!"