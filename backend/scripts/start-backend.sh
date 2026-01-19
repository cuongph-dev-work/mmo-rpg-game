#!/bin/bash
# Kill existing processes on ports 3000, 3001, 3002
lsof -t -i:3000 -i:3001 -i:3002 | xargs kill -9 2>/dev/null

echo "Starting Backend Services..."

# Start Auth Service
node dist/apps/auth-service/main.js > auth.log 2>&1 &
AUTH_PID=$!
echo "Auth Service started (PID: $AUTH_PID)"

# Start World Directory
node dist/apps/world-directory/main.js > world.log 2>&1 &
WORLD_PID=$!
echo "World Directory started (PID: $WORLD_PID)"

# Start Gateway Service
node dist/apps/gateway-service/main.js > gateway.log 2>&1 &
GATEWAY_PID=$!
echo "Gateway Service started (PID: $GATEWAY_PID)"

echo "All services running. Check *.log files for output."
echo "Use 'pkill -P $$' to stop."
