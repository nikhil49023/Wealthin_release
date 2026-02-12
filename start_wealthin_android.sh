#!/bin/bash
# WealthIn Android startup script
# Runs Flutter app on an Android emulator/device.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_DIR="$SCRIPT_DIR/frontend/wealthin_flutter"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║             WealthIn Android Startup                     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

cd "$FLUTTER_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo -e "${RED}Flutter is not installed or not in PATH.${NC}"
  exit 1
fi

echo -e "${GREEN}[1/3] Checking connected Android devices...${NC}"
DEVICE_ID=$(flutter devices | awk -F'•' '/android|emulator/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}')

launch_emulator() {
  local emulator_id
  emulator_id=$(flutter emulators | awk -F'•' '/^[[:space:]]*[0-9]+[[:space:]]*•/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}')

  if [ -z "$emulator_id" ]; then
    echo -e "${RED}No Android emulator found. Create one in Android Studio first.${NC}"
    exit 1
  fi

  echo -e "${GREEN}[2/3] Launching emulator: ${emulator_id}${NC}"
  flutter emulators --launch "$emulator_id" >/dev/null 2>&1 || true

  echo -e "${YELLOW}Waiting for emulator to boot...${NC}"
  for _ in $(seq 1 30); do
    DEVICE_ID=$(flutter devices | awk -F'•' '/android|emulator/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}')
    if [ -n "$DEVICE_ID" ]; then
      break
    fi
    sleep 4
    echo -n "."
  done
  echo ""
}

if [ -z "$DEVICE_ID" ]; then
  launch_emulator
fi

if [ -z "$DEVICE_ID" ]; then
  echo -e "${RED}No Android device/emulator available.${NC}"
  exit 1
fi

echo -e "${GREEN}[3/3] Running app on: ${DEVICE_ID}${NC}"
flutter run -d "$DEVICE_ID"
