#!/bin/bash
# Scout Analytics Engine Setup Script
# Zero-subscription analytics with Azure SQL backend

set -e

echo "🚀 Scout Analytics Engine Setup"
echo "================================"

# Check Python version
echo "📋 Checking Python version..."
python3 --version
if [ $? -ne 0 ]; then
    echo "❌ Python 3 not found. Please install Python 3.8+"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "🔧 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "⚡ Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "📦 Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📚 Installing Scout Engine dependencies..."
pip install -r requirements-scout-engine.txt

# Check Azure SQL connection
echo "🔗 Checking Azure SQL connection..."
if [ -n "$AZURE_SQL_CONN_STR" ]; then
    echo "✅ AZURE_SQL_CONN_STR environment variable found"
else
    echo "⚠️  AZURE_SQL_CONN_STR not set - checking macOS Keychain..."

    # Try to read from macOS Keychain
    if security find-generic-password -s "SQL-TBWA-ProjectScout-Reporting-Prod" -a "scout-analytics" -w 2>/dev/null; then
        echo "✅ Azure SQL credentials found in Keychain"
    else
        echo "❌ No Azure SQL connection configured"
        echo ""
        echo "💡 Please configure Azure SQL connection:"
        echo "   Option 1 (Environment Variable):"
        echo "   export AZURE_SQL_CONN_STR='your_connection_string'"
        echo ""
        echo "   Option 2 (macOS Keychain):"
        echo "   security add-generic-password -U \\"
        echo "     -s 'SQL-TBWA-ProjectScout-Reporting-Prod' \\"
        echo "     -a 'scout-analytics' \\"
        echo "     -w '<your_connection_string>'"
        echo ""
    fi
fi

# Test ChromaDB setup
echo "🧠 Testing ChromaDB setup..."
python3 -c "import chromadb; print('✅ ChromaDB working')" || echo "❌ ChromaDB test failed"

# Test sentence-transformers
echo "🔤 Testing sentence-transformers..."
python3 -c "from sentence_transformers import SentenceTransformer; print('✅ Sentence transformers working')" || echo "❌ Sentence transformers test failed"

# Optional: Check for Ollama
echo "🦙 Checking for Ollama (optional local LLM)..."
if command -v ollama &> /dev/null; then
    echo "✅ Ollama found - local LLM available"
    ollama list 2>/dev/null || echo "   No models installed yet"
else
    echo "ℹ️  Ollama not found (optional)"
    echo "   Install with: curl -fsSL https://ollama.ai/install.sh | sh"
    echo "   Then: ollama pull llama3.2"
fi

# Create startup script
echo "📝 Creating startup script..."
cat > start-scout-engine.sh << 'EOF'
#!/bin/bash
# Scout Analytics Engine Startup Script

echo "🚀 Starting Scout Analytics Engine..."

# Activate virtual environment
source venv/bin/activate

# Start the Flask API server
echo "🌐 Starting API server on http://localhost:5000"
python3 scout-api-server.py
EOF

chmod +x start-scout-engine.sh

# Create test script
echo "🧪 Creating test script..."
cat > test-scout-engine.sh << 'EOF'
#!/bin/bash
# Scout Analytics Engine Test Script

echo "🧪 Testing Scout Analytics Engine..."

# Activate virtual environment
source venv/bin/activate

# Test the engine directly
echo "📊 Testing analytics engine..."
python3 scout-analytics-engine.py

echo ""
echo "🌐 Testing API endpoints..."
echo "Starting API server in background..."

# Start API server in background
python3 scout-api-server.py &
API_PID=$!

# Wait for server to start
sleep 3

# Test endpoints
echo "Testing health endpoint..."
curl -s http://localhost:5000/health | python3 -m json.tool

echo ""
echo "Testing summary analysis..."
curl -s http://localhost:5000/api/analyze?type=summary | python3 -m json.tool

echo ""
echo "Testing natural language query..."
curl -s "http://localhost:5000/api/query?q=top 3 brands" | python3 -m json.tool

# Stop API server
kill $API_PID 2>/dev/null

echo ""
echo "✅ Tests completed!"
EOF

chmod +x test-scout-engine.sh

echo ""
echo "✅ Scout Analytics Engine setup complete!"
echo ""
echo "🎯 Next steps:"
echo "   1. Configure Azure SQL connection (see above)"
echo "   2. Start the engine: ./start-scout-engine.sh"
echo "   3. Test the setup: ./test-scout-engine.sh"
echo ""
echo "🔗 API will be available at: http://localhost:5000"
echo "📚 API documentation: http://localhost:5000/api/spec"
echo ""
echo "🏥 Health check: curl http://localhost:5000/health"
echo "🔍 Query example: curl 'http://localhost:5000/api/query?q=top 5 brands'"
echo "📊 Analysis: curl 'http://localhost:5000/api/analyze?type=summary'"
echo ""
echo "🎉 Ready for baseline UI integration!"