#!/bin/bash
# WealthIn startup entrypoint (Android-only)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "WealthIn is Android-only in this branch."
echo "Launching Android startup flow..."
exec "$SCRIPT_DIR/start_wealthin_android.sh"
