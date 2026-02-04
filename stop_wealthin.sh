#!/bin/bash
# WealthIn Stop Script - Stops all services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEALTHIN_DIR="$SCRIPT_DIR/wealthin"
SERVER_DIR="$WEALTHIN_DIR/wealthin_server"
FLUTTER_DIR="$SCRIPT_DIR/frontend/wealthin_flutter"
SIDECAR_DIR="$SCRIPT_DIR/backend"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Stopping WealthIn services...${NC}"

# Stop Flutter
if [ -f "$FLUTTER_DIR/flutter.pid" ]; then
    PID=$(cat "$FLUTTER_DIR/flutter.pid")
    if ps -p $PID > /dev/null 2>&1; then
        kill $PID 2>/dev/null
        echo -e "  ✓ Flutter app stopped (PID: $PID)"
    fi
    rm -f "$FLUTTER_DIR/flutter.pid"
fi



# Stop Sidecar
if [ -f "$SIDECAR_DIR/sidecar.pid" ]; then
    PID=$(cat "$SIDECAR_DIR/sidecar.pid")
    if ps -p $PID > /dev/null 2>&1; then
        kill $PID 2>/dev/null
        echo -e "  ✓ Python sidecar stopped (PID: $PID)"
    fi
    rm -f "$SIDECAR_DIR/sidecar.pid"
fi

# Kill any remaining processes on the ports
for port in 8000 8082 8085; do
    pid=$(lsof -t -i:$port 2>/dev/null || fuser $port/tcp 2>/dev/null | awk '{print $1}')
    if [ -n "$pid" ]; then
        kill -9 $pid 2>/dev/null || true
        echo -e "  ✓ Killed process on port $port"
    fi
done

echo -e "${GREEN}All WealthIn services stopped.${NC}"
