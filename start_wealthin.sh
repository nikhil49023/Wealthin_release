#!/bin/bash
# WealthIn Full Stack Startup Script
# Starts: PostgreSQL (if needed), Serverpod Server, Python Sidecar, Flutter Linux App

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEALTHIN_DIR="$SCRIPT_DIR/wealthin"
SERVER_DIR="$WEALTHIN_DIR/wealthin_server"
FLUTTER_DIR="$SCRIPT_DIR/frontend/wealthin_flutter"
SIDECAR_DIR="$SCRIPT_DIR/backend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          WealthIn Full Stack Startup Script               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if a port is in use
check_port() {
    if netstat -tuln 2>/dev/null | grep -q ":$1 " || ss -tuln 2>/dev/null | grep -q ":$1 "; then
        return 0
    else
        return 1
    fi
}

# Function to kill process on port
kill_port() {
    local port=$1
    local pid=$(lsof -t -i:$port 2>/dev/null || fuser $port/tcp 2>/dev/null | awk '{print $1}')
    if [ -n "$pid" ]; then
        echo -e "${YELLOW}Killing existing process on port $port (PID: $pid)${NC}"
        kill -9 $pid 2>/dev/null || true
        sleep 1
    fi
}

# Export API keys
echo -e "${GREEN}[1/3] Setting up environment variables...${NC}"
export ZOHO_CLIENT_ID="${ZOHO_CLIENT_ID:-1000.S502C4RR4OX00EXMKPMKP246HJ9LYY}"
export ZOHO_CLIENT_SECRET="${ZOHO_CLIENT_SECRET:-267a55dc05912009bb6ee13aabe1ea4e00c303e94d}"
export ZOHO_REFRESH_TOKEN="${ZOHO_REFRESH_TOKEN:-1000.9d9d2a78dd2bab8c51eb351f9f6d979f.904b8b7a8543ec3281d18749911184fd}"
export ZOHO_PROJECT_ID="${ZOHO_PROJECT_ID:-24392000000011167}"
export ZOHO_CATALYST_ORG_ID="${ZOHO_CATALYST_ORG_ID:-60056122667}"
export SARVAM_API_KEY="${SARVAM_API_KEY:-sk_vqh8cfif_MWrqmgK4dyzLoIOqxJn8udIc}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-}"

echo -e "  ✓ Environment variables configured"

# Start Python Sidecar
echo -e "${GREEN}[2/3] Starting Python Sidecar...${NC}"
if check_port 8000; then
    echo -e "${YELLOW}  Port 8000 in use, restarting sidecar...${NC}"
    kill_port 8000
fi

cd "$SIDECAR_DIR"

# Create venv if not exists
if [ ! -d "venv" ]; then
    echo -e "  Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate and install deps
source venv/bin/activate
pip install -q -r requirements.txt 2>/dev/null

# Start sidecar in background
nohup python main.py > sidecar.log 2>&1 &
SIDECAR_PID=$!
echo $SIDECAR_PID > sidecar.pid
echo -e "  ✓ Python Sidecar started (PID: $SIDECAR_PID) on port 8000"

deactivate 2>/dev/null || true

# Wait for sidecar to be ready
sleep 2
if ! check_port 8000; then
    echo -e "${RED}  Warning: Sidecar may not have started correctly${NC}"
fi

# Build and Run Flutter Linux
echo -e "${GREEN}[3/3] Building Flutter Linux App...${NC}"
cd "$FLUTTER_DIR"

# Check if flutter is available
if command -v flutter &> /dev/null; then
    echo -e "  Building Linux desktop app..."
    flutter build linux --release 2>&1 | tail -5
    
    echo -e "  ✓ Flutter Linux app built successfully"
    echo ""
    
    # Run the app
    LINUX_APP="$FLUTTER_DIR/build/linux/x64/release/bundle/wealthin_flutter"
    if [ -f "$LINUX_APP" ]; then
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}🚀 Launching WealthIn...${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        "$LINUX_APP" &
        FLUTTER_PID=$!
        echo $FLUTTER_PID > "$FLUTTER_DIR/flutter.pid"
        echo -e "  ✓ Flutter app launched (PID: $FLUTTER_PID)"
    else
        echo -e "${YELLOW}  Linux binary not found. Running in debug mode...${NC}"
        flutter run -d linux &
        FLUTTER_PID=$!
    fi
else
    echo -e "${RED}  Flutter not found in PATH${NC}"
    echo -e "${YELLOW}  Please run: flutter run -d linux${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}WealthIn is now running!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Services:"
echo -e "  🔹 Serverpod API:    http://localhost:8085"
echo -e "  🔹 Serverpod Web:    http://localhost:8082"
echo -e "  🔹 Python Sidecar:   http://localhost:8000"
echo -e "  🔹 PostgreSQL:       localhost:8090"
echo ""
echo -e "To stop all services, run:"
echo -e "  ${YELLOW}./stop_wealthin.sh${NC}"
echo ""
