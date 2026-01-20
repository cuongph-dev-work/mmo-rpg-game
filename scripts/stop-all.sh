#!/bin/bash

# MMO RPG Game - Stop All Services Script

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
LOGS_DIR="$PROJECT_ROOT/logs"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Stopping all services...${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Function to kill processes on specific ports
kill_port() {
    local port=$1
    local pids=$(lsof -ti:$port 2>/dev/null || true)
    if [ ! -z "$pids" ]; then
        echo -e "${RED}✗${NC} Killing processes on port $port"
        echo "$pids" | xargs kill -9 2>/dev/null || true
    fi
}

# Kill by ports
kill_port 3000  # Auth Service
kill_port 3001  # World Directory
kill_port 3002  # Gateway Service
kill_port 4001  # Map Server (Godot headless only)

# Kill Godot headless server specifically (not client)
# Only kill processes with --headless flag
echo -e "${RED}✗${NC} Stopping Map Server (headless only)"
pkill -f "godot --headless" 2>/dev/null || true

# Kill PIDs from file if exists
if [ -f "$LOGS_DIR/.pids" ]; then
    echo -e "${RED}✗${NC} Killing saved PIDs"
    cat "$LOGS_DIR/.pids" | xargs kill -9 2>/dev/null || true
    rm "$LOGS_DIR/.pids"
fi

echo ""
echo -e "${GREEN}✓ All services stopped${NC}"
echo ""
