#!/bin/bash

# Kill existing processes on ports
echo "Killing existing processes on ports 3000, 3001, 3002..."
lsof -t -i:3000 -i:3001 -i:3002 | xargs kill -9 2>/dev/null

echo "Starting Backend Services in DEV mode..."

# Start Auth Service (port 3000)
cd apps/auth-service
PORT=3000 npx nest start --watch > ../../logs/auth.log 2>&1 &
AUTH_PID=$!
echo "✅ Auth Service starting (PID: $AUTH_PID) on port 3000"
cd ../..

sleep 2

# Start World Directory (port 3001)
cd apps/world-directory  
PORT=3001 npx nest start --watch > ../../logs/world.log 2>&1 &
WORLD_PID=$!
echo "✅ World Directory starting (PID: $WORLD_PID) on port 3001"
cd ../..

sleep 2

# Start Gateway Service (port 3002)
cd apps/gateway-service
GATEWAY_PORT=3002 npx nest start --watch > ../../logs/gateway.log 2>&1 &
GATEWAY_PID=$!
echo "✅ Gateway Service starting (PID: $GATEWAY_PID) on port 3002"
cd ../..

echo ""
echo "🚀 All services starting in watch mode!"
echo "📝 Check logs/ folder for output:"
echo "   - logs/auth.log"
echo "   - logs/world.log"
echo "   - logs/gateway.log"
echo ""
echo "⚠️  Services may take 10-30 seconds to fully start"
echo "🛑 To stop all services: pkill -f 'nest start'"
