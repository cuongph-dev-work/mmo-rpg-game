#!/bin/bash

# MMO RPG Game - Unified Startup Script
# Starts all backend services and Map Server

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
LOGS_DIR="$PROJECT_ROOT/logs"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  MMO RPG Game - Unified Startup${NC}"
echo -e "${BLUE}========================================${NC}"

# Create logs directory
mkdir -p "$LOGS_DIR"
echo -e "${GREEN}✓${NC} Logs directory: $LOGS_DIR"

# Function to kill processes on specific ports
kill_port() {
    local port=$1
    local pids=$(lsof -ti:$port 2>/dev/null || true)
    if [ ! -z "$pids" ]; then
        echo -e "${YELLOW}⚠${NC} Killing existing processes on port $port"
        echo "$pids" | xargs kill -9 2>/dev/null || true
        sleep 0.5
    fi
}

# Function to kill Godot headless server only (not client)
kill_godot_server() {
    echo -e "${YELLOW}⚠${NC} Killing existing Godot headless server"
    pkill -f "godot --headless" 2>/dev/null || true
    sleep 0.5
}

echo ""
echo -e "${BLUE}[1/2] Cleaning up existing processes...${NC}"
kill_port 3000  # Auth Service
kill_port 3001  # World Directory
kill_port 3002  # Gateway Service
kill_port 4001  # Map Server
kill_godot_server

echo ""
echo -e "${BLUE}[2/2] Starting services...${NC}"

# Start Backend Services
echo -e "${GREEN}🚀${NC} Starting Auth Service (port 3000)..."
cd "$PROJECT_ROOT/backend/apps/auth-service"
npx nest start --watch > "$LOGS_DIR/auth.log" 2>&1 &
AUTH_PID=$!
echo -e "   PID: $AUTH_PID | Log: logs/auth.log"
cd "$PROJECT_ROOT"

sleep 2

echo -e "${GREEN}🚀${NC} Starting World Directory (port 3001)..."
cd "$PROJECT_ROOT/backend/apps/world-directory"
npx nest start --watch > "$LOGS_DIR/world.log" 2>&1 &
WORLD_PID=$!
echo -e "   PID: $WORLD_PID | Log: logs/world.log"
cd "$PROJECT_ROOT"

sleep 2

echo -e "${GREEN}🚀${NC} Starting Gateway Service (port 3002)..."
cd "$PROJECT_ROOT/backend/apps/gateway-service"
npx nest start --watch > "$LOGS_DIR/gateway.log" 2>&1 &
GATEWAY_PID=$!
echo -e "   PID: $GATEWAY_PID | Log: logs/gateway.log"
cd "$PROJECT_ROOT"

sleep 3

# Start Map Server
cd "$PROJECT_ROOT/server"

echo -e "${GREEN}🚀${NC} Starting Map Server (Map 1, port 4001)..."
./start_server.sh 1 4001 > "$LOGS_DIR/map_server.log" 2>&1 &
MAP_PID=$!
echo -e "   PID: $MAP_PID | Log: logs/map_server.log"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  All services started!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Service Status:${NC}"
echo -e "  Auth Service:      http://localhost:3000 (PID: $AUTH_PID)"
echo -e "  World Directory:   http://localhost:3001 (PID: $WORLD_PID)"
echo -e "  Gateway Service:   ws://localhost:3002/ws (PID: $GATEWAY_PID)"
echo -e "  Map Server:        ENet Port 4001 (PID: $MAP_PID)"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo -e "  All logs: $LOGS_DIR"
echo -e "  tail -f logs/auth.log"
echo -e "  tail -f logs/world.log"
echo -e "  tail -f logs/gateway.log"
echo -e "  tail -f logs/map_server.log"
echo ""
echo -e "${YELLOW}Press Ctrl+C to view stop instructions${NC}"
echo ""

# Save PIDs to file for easy cleanup
echo "$AUTH_PID" > "$LOGS_DIR/.pids"
echo "$WORLD_PID" >> "$LOGS_DIR/.pids"
echo "$GATEWAY_PID" >> "$LOGS_DIR/.pids"
echo "$MAP_PID" >> "$LOGS_DIR/.pids"

# Wait for Ctrl+C
trap ctrl_c INT

function ctrl_c() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  To stop all services, run:${NC}"
    echo -e "${YELLOW}  ./scripts/stop-all.sh${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    exit 0
}

# Keep script running
wait
