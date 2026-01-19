#!/bin/bash

# Start Game Server
# Usage: ./start_server.sh [map_id] [port]
# Example: ./start_server.sh 1 3001

MAP_ID=${1:-1}
PORT=${2:-3001}

echo "Starting Game Server..."
echo "Map ID: $MAP_ID"
echo "Port: $PORT"
echo ""

godot --headless --map-id=$MAP_ID --port=$PORT
