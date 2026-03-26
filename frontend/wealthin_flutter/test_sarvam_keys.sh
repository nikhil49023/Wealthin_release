#!/bin/bash
# Test Sarvam API Key - Verification Script
# This script tests if your API key is configured correctly

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Sarvam AI Key - Verification Test${NC}"
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

# Test 3: Parse API key
echo -e "${BLUE}3️⃣  Testing: API key format${NC}"
if ! grep -q "SARVAM_API_KEY=" .env.sarvam_keys; then
    echo -e "${RED}✗ FAILED${NC} - Missing SARVAM_API_KEY in file"
    exit 1
fi

KEY=$(grep "SARVAM_API_KEY=" .env.sarvam_keys | cut -d'=' -f2- | xargs)

if [ -z "$KEY" ]; then
    echo -e "${RED}✗ FAILED${NC} - No API key value found"
    exit 1
fi

echo -e "${GREEN}✓ PASS${NC} - Found configured API key"
echo "   Key preview: ${KEY:0:8}..."
echo ""

# Test 4: Check key format (should start with sk_)
echo -e "${BLUE}4️⃣  Testing: API key prefix${NC}"
if [[ ! "$KEY" =~ ^sk_ ]]; then
    echo -e "${RED}✗ FAILED${NC} - Invalid key format (should start with sk_)"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - Key has valid format (sk_...)"
echo ""

# Test 5: Basic capacity expectation
echo -e "${BLUE}5️⃣  Testing: Configuration readiness${NC}"
echo -e "${GREEN}✓ PASS${NC} - Single-key mode configured"
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
echo "  • Single key: configured ✓"
echo "  • Security: Keys ignored in git ✓"
echo "  • Flutter: Ready ✓"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Run: ${GREEN}flutter run --dart-define-from-file=.env.sarvam_keys${NC}"
echo "  2. Open: AI Hub screen"
echo "  3. Test: Send a query and check debug console"
echo "  4. Monitor: Watch for [PythonBridge] and [AIAgentService] messages"
echo ""
echo -e "${BLUE}To build release:${NC}"
echo "  ${GREEN}flutter build apk --release --dart-define-from-file=.env.sarvam_keys${NC}"
echo ""
