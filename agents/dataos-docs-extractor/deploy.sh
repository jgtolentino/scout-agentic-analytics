#!/bin/bash
# DataOS Documentation Extractor Deployment Script

echo "🚀 DataOS Documentation Extractor Deployment"
echo "==========================================="

# Check Python version
echo "🐍 Checking Python version..."
python3 --version

# Create virtual environment
echo "📦 Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Install Playwright browsers
echo "🌐 Installing Playwright browsers..."
playwright install chromium
playwright install-deps

# Create necessary directories
echo "📁 Creating archive directories..."
mkdir -p /dataos-archives/{archives,diffs,schedules}

# Set permissions
echo "🔐 Setting permissions..."
chmod +x main.py api.py test_extractor.py

# Run tests
echo "🧪 Running tests..."
python test_extractor.py

# Create systemd service (optional)
echo "⚙️ Creating systemd service..."
cat > dataos-extractor.service << EOF
[Unit]
Description=DataOS Documentation Extractor API
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
Environment="PATH=$(pwd)/venv/bin:$PATH"
ExecStart=$(pwd)/venv/bin/python api.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Deployment complete!"
echo ""
echo "To start the API server:"
echo "  python api.py"
echo ""
echo "To run the CLI:"
echo "  python main.py --help"
echo ""
echo "To install as systemd service:"
echo "  sudo cp dataos-extractor.service /etc/systemd/system/"
echo "  sudo systemctl enable dataos-extractor"
echo "  sudo systemctl start dataos-extractor"