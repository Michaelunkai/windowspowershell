#!/bin/bash

echo "🧪 Testing TovPlay API Endpoints..."
echo "=================================="
echo

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed or not in PATH"
    exit 1
fi

# Check if server is running
echo "🔍 Checking if API server is running..."
if curl -s http://localhost:5001/health > /dev/null; then
    echo "✅ API server is responding"
else
    echo "⚠️  Warning: API server may not be running at http://localhost:5001"
    echo "   Starting tests anyway..."
fi

echo

# Run the API endpoint tests
python3 scripts/test_api_endpoints.py --url http://localhost:5001 --save-report

echo
echo "✨ Testing completed!"