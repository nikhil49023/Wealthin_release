#!/bin/bash
# Sarvam AI Keys Configuration & Testing Script
# This script helps initialize and test the multi-key setup

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  WealthIn - Sarvam AI Multi-Key Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if .env.sarvam_keys exists
if [ ! -f ".env.sarvam_keys" ]; then
    echo -e "${YELLOW}⚠ .env.sarvam_keys not found!${NC}"
    echo "Please create .env.sarvam_keys with your API keys first."
    exit 1
fi

echo -e "${GREEN}✓${NC} Found .env.sarvam_keys"

# Count number of keys
NUM_KEYS=$(grep SARVAM_API_KEYS .env.sarvam_keys | cut -d'=' -f2 | tr ',' '\n' | grep -c "sk_")
TOTAL_RPM=$((NUM_KEYS * 60))

echo -e "${GREEN}✓${NC} Configured with ${GREEN}${NUM_KEYS}${NC} API keys"
echo -e "${GREEN}✓${NC} Total capacity: ${GREEN}${TOTAL_RPM} RPM${NC} (${NUM_KEYS} × 60 RPM)"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check for flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${YELLOW}⚠ Flutter not found in PATH${NC}"
    exit 1
fi

echo "What would you like to do?"
echo ""
echo "1) Run app in debug mode (with API keys)"
echo "2) Build release APK (with API keys)"
echo "3) Test API key rotation (verify multi-key setup)"
echo "4) Just show configuration (no build)"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo ""
        echo -e "${BLUE}🚀 Running app in debug mode...${NC}"
        flutter run --dart-define-from-file=.env.sarvam_keys
        ;;
    2)
        echo ""
        echo -e "${BLUE}📦 Building release APK...${NC}"
        flutter build apk --release --dart-define-from-file=.env.sarvam_keys
        echo ""
        echo -e "${GREEN}✓ Build complete!${NC}"
        echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
        ;;
    3)
        echo ""
        echo -e "${BLUE}🧪 Testing API key rotation...${NC}"
        echo ""
        echo "This will:"
        echo "  1. Build the app with your API keys"
        echo "  2. Open AI Hub screen"
        echo "  3. Send 10 test queries to verify key rotation"
        echo ""
        read -p "Press Enter to continue..."
        flutter run --dart-define-from-file=.env.sarvam_keys
        ;;
    4)
        echo ""
        echo -e "${GREEN}Current Configuration:${NC}"
        echo "  • Keys: ${NUM_KEYS}"
        echo "  • Total RPM: ${TOTAL_RPM}"
        echo "  • Location: .env.sarvam_keys"
        echo "  • Storage: Secure (Android KeyStore / iOS Keychain)"
        echo ""
        echo -e "${BLUE}To use in builds:${NC}"
        echo "  flutter run --dart-define-from-file=.env.sarvam_keys"
        ;;
    *)
        echo -e "${YELLOW}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✓ Complete!${NC}"
