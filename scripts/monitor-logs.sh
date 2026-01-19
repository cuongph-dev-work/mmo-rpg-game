#!/bin/bash

# MMO RPG Game - Monitor All Logs
# Opens all service logs in split panes

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
LOGS_DIR="$PROJECT_ROOT/logs"

# Check if logs exist
if [ ! -d "$LOGS_DIR" ]; then
    echo "Logs directory not found. Start services first with ./start-all.sh"
    exit 1
fi

echo "Monitoring all logs in $LOGS_DIR"
echo "Press Ctrl+C to exit"
echo ""

# Use multitail if available, otherwise fall back to tail
if command -v multitail &> /dev/null; then
    multitail \
        -s 4 \
        -l "tail -f $LOGS_DIR/auth.log" \
        -l "tail -f $LOGS_DIR/world.log" \
        -l "tail -f $LOGS_DIR/gateway.log" \
        -l "tail -f $LOGS_DIR/map_server.log"
else
    # Fallback: use tail with color coding
    tail -f \
        "$LOGS_DIR/auth.log" \
        "$LOGS_DIR/world.log" \
        "$LOGS_DIR/gateway.log" \
        "$LOGS_DIR/map_server.log"
fi
