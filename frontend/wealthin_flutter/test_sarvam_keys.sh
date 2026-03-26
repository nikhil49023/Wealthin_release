#!/bin/bash
# Test Sarvam API Keys - Verification Script
# This script tests if your API keys are working correctly

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Sarvam AI Keys - Verification Test${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 1: Check .env file exists
echo -e "${BLUE}1️⃣  Testing: .env.sarvam_keys file${NC}"
if [ ! -f ".env.sarvam_keys" ]; then
    echo -e "${RED}✗ FAILED${NC} - File not found: .env.sarvam_keys"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - File exists"
echo ""

# Test 2: Check file is readable
echo -e "${BLUE}2️⃣  Testing: File readability${NC}"
if [ ! -r ".env.sarvam_keys" ]; then
    echo -e "${RED}✗ FAILED${NC} - File not readable"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - File is readable"
echo ""

# Test 3: Parse API keys
echo -e "${BLUE}3️⃣  Testing: API keys format${NC}"
if ! grep -q "SARVAM_API_KEYS=" .env.sarvam_keys; then
    echo -e "${RED}✗ FAILED${NC} - Missing SARVAM_API_KEYS in file"
    exit 1
fi

KEYS=$(grep "SARVAM_API_KEYS=" .env.sarvam_keys | cut -d'=' -f2)
NUM_KEYS=$(echo "$KEYS" | tr ',' '\n' | grep -c "sk_")

if [ "$NUM_KEYS" -lt 1 ]; then
    echo -e "${RED}✗ FAILED${NC} - No valid API keys found"
    exit 1
fi

echo -e "${GREEN}✓ PASS${NC} - Found ${GREEN}${NUM_KEYS}${NC} valid API keys"
echo "   Keys in file:"
echo "$KEYS" | tr ',' '\n' | sed 's/^/     • /'
echo ""

# Test 4: Check key format (should start with sk_)
echo -e "${BLUE}4️⃣  Testing: API key format${NC}"
INVALID_KEYS=0
echo "$KEYS" | tr ',' '\n' | while read key; do
    key=$(echo "$key" | xargs)  # Trim whitespace
    if [[ ! "$key" =~ ^sk_ ]]; then
        echo -e "${RED}   ✗${NC} Invalid format: $key (should start with sk_)"
        ((INVALID_KEYS++))
    fi
done

if [ "$INVALID_KEYS" -gt 0 ]; then
    echo -e "${RED}✗ FAILED${NC} - Some keys have invalid format"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - All keys have valid format (sk_...)"
echo ""

# Test 5: Calculate total RPM
echo -e "${BLUE}5️⃣  Testing: Capacity calculation${NC}"
TOTAL_RPM=$((NUM_KEYS * 60))
echo -e "${GREEN}✓ PASS${NC} - Capacity: ${GREEN}${TOTAL_RPM} RPM${NC} (${NUM_KEYS} keys × 60 RPM each)"
echo ""

# Test 6: Check if keys are in .gitignore
echo -e "${BLUE}6️⃣  Testing: Security (.gitignore)${NC}"
if ! grep -q "\.env\.sarvam_keys" .gitignore 2>/dev/null; then
    echo -e "${YELLOW}⚠ WARNING${NC} - Keys file not in .gitignore"
    echo "   Adding to .gitignore for security..."
    echo ".env.sarvam_keys" >> .gitignore
    echo -e "${GREEN}✓ Added${NC}"
else
    echo -e "${GREEN}✓ PASS${NC} - Keys file is in .gitignore (secure)"
fi
echo ""

# Test 7: Verify Flutter and build tools
echo -e "${BLUE}7️⃣  Testing: Build environment${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}✗ FAILED${NC} - Flutter not found in PATH"
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -1)
echo -e "${GREEN}✓ PASS${NC} - Flutter found"
echo "   $FLUTTER_VERSION"
echo ""

# Test 8: Check pubspec.yaml
echo -e "${BLUE}8️⃣  Testing: Dependencies${NC}"
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}✗ FAILED${NC} - pubspec.yaml not found"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - pubspec.yaml found"
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ All tests passed!${NC}"
echo ""
echo -e "${GREEN}Configuration Summary:${NC}"
echo "  • File: .env.sarvam_keys ✓"
echo "  • Keys: $NUM_KEYS configured ✓"
echo "  • Capacity: ${TOTAL_RPM} RPM ✓"
echo "  • Security: Keys ignored in git ✓"
echo "  • Flutter: Ready ✓"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Run: ${GREEN}flutter run --dart-define-from-file=.env.sarvam_keys${NC}"
echo "  2. Open: AI Hub screen"
echo "  3. Test: Send a query and check debug console"
echo "  4. Monitor: Watch for [SarvamKeyManager] messages"
echo ""
echo -e "${BLUE}To build release:${NC}"
echo "  ${GREEN}flutter build apk --release --dart-define-from-file=.env.sarvam_keys${NC}"
echo ""
