#!/bin/bash
# Setup script for Wealthin Web Scraper System

set -e

echo "🛍️ Wealthin Marketplace Scraper Setup"
echo "======================================"
echo ""

# Check Python version
echo "✓ Checking Python..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "  Python version: $PYTHON_VERSION"

# Navigate to scrapers directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRAPERS_DIR="$SCRIPT_DIR/scrapers"

echo ""
echo "📁 Setting up in: $SCRAPERS_DIR"
cd "$SCRAPERS_DIR"

# Create virtual environment if not exists
if [ ! -d "venv" ]; then
  echo "📦 Creating virtual environment..."
  python3 -m venv venv
  echo "✓ Virtual environment created"
else
  echo "✓ Virtual environment already exists"
fi

# Activate virtual environment
echo ""
echo "🔧 Activating virtual environment..."
source venv/bin/activate
echo "✓ Virtual environment activated"

# Install requirements
echo ""
echo "📥 Installing dependencies..."
pip install --upgrade pip > /dev/null 2>&1
pip install -r requirements.txt > /dev/null 2>&1
echo "✓ Dependencies installed"

# Verify installation
echo ""
echo "✓ Verifying installation..."
python3 -c "import requests, bs4, aiohttp, flask; print('  All dependencies verified')"

# Show startup command
echo ""
echo "======================================"
echo "✅ Setup Complete!"
echo ""
echo "To start the Flask API server, run:"
echo "  cd $SCRAPERS_DIR"
echo "  source venv/bin/activate  # On Windows: venv\\Scripts\\activate"
echo "  python flask_scraper_api.py"
echo ""
echo "The API will be available at: http://localhost:5001"
echo "Test endpoint: curl http://localhost:5001/health"
echo "======================================"
