#!/usr/bin/env python3
"""
TBWA Project Scout - MCP Orchestration Script
Coordinates MindsDB and SuperClaude Context7 for AI analytics integration

Usage:
    python mcp_orchestrator.py --action [init|test|analyze|predict]
    python mcp_orchestrator.py --help
"""

import os
import sys
import json
import subprocess
import argparse
import requests
from typing import Dict, List, Optional, Any
from datetime import datetime

class MCPOrchestrator:
    """MCP Server Orchestration for TBWA Project Scout"""
    
    def __init__(self):
        self.credentials = {}
        self.mcp_server_path = os.path.expanduser("~/mcp-mindsdb")
        self.mindsdb_config = {}
        self.load_credentials()
    
    def load_credentials(self):
        """Load credentials for local MindsDB setup"""
        print("🔐 Setting up local MindsDB configuration...")
        
        # MindsDB local setup only - Zilliz replaced by SuperClaude Context7
        self.credentials = {
            'mindsdb': {
                'local_url': 'http://127.0.0.1:47334',  # MindsDB local server
                'mode': 'local',
                'installed': False  # Will check during connection test
            }
        }
        
        print("✅ Local MindsDB configuration ready")
        print("🎯 Using SuperClaude Context7 for code context (Zilliz deprecated)")
    
    def test_mindsdb_connection(self) -> bool:
        """Test local MindsDB installation and connection"""
        print("🤖 Testing local MindsDB...")
        
        # First check if MindsDB is installed
        try:
            result = subprocess.run(['pip', 'show', 'mindsdb'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode != 0:
                print("📦 MindsDB not installed. Installing...")
                self._install_mindsdb()
                return self.test_mindsdb_connection()  # Retry after installation
        except subprocess.TimeoutExpired:
            print("⚠️  pip command timed out, assuming MindsDB needs installation")
        except Exception as e:
            print(f"⚠️  Could not check MindsDB installation: {e}")
        
        # Check if MindsDB server is running
        try:
            response = requests.get(f"{self.credentials['mindsdb']['local_url']}/api/status", timeout=5)
            if response.status_code == 200:
                print("✅ Local MindsDB server is running")
                self.credentials['mindsdb']['installed'] = True
                return True
        except requests.exceptions.ConnectionError:
            print("🚀 MindsDB server not running. Starting...")
            return self._start_mindsdb_server()
        except Exception as e:
            print(f"⚠️  MindsDB server check failed: {e}")
            return self._start_mindsdb_server()
        
        return False
    
    def _install_mindsdb(self) -> bool:
        """Install MindsDB locally"""
        try:
            print("📦 Installing MindsDB (this may take a few minutes)...")
            result = subprocess.run(['pip', 'install', 'mindsdb'], 
                                  capture_output=True, text=True, timeout=300)
            if result.returncode == 0:
                print("✅ MindsDB installed successfully")
                return True
            else:
                print(f"❌ MindsDB installation failed: {result.stderr}")
                return False
        except subprocess.TimeoutExpired:
            print("❌ MindsDB installation timed out")
            return False
        except Exception as e:
            print(f"❌ MindsDB installation error: {e}")
            return False
    
    def _start_mindsdb_server(self) -> bool:
        """Start local MindsDB server"""
        try:
            print("🚀 Starting MindsDB server...")
            # Start MindsDB in background
            process = subprocess.Popen(['python', '-m', 'mindsdb', '--api=http'], 
                                     stdout=subprocess.PIPE, 
                                     stderr=subprocess.PIPE)
            
            # Wait a moment for server to start
            import time
            time.sleep(10)
            
            # Check if server is now running
            try:
                response = requests.get(f"{self.credentials['mindsdb']['local_url']}/api/status", timeout=5)
                if response.status_code == 200:
                    print("✅ MindsDB server started successfully")
                    return True
            except:
                pass
            
            print("⚠️  MindsDB server may be starting (check manually with: python -m mindsdb --api=http)")
            return False
            
        except Exception as e:
            print(f"❌ Failed to start MindsDB server: {e}")
            print("💡 Try manually: python -m mindsdb --api=http")
            return False
    
    def test_context7_integration(self) -> bool:
        """Test SuperClaude Context7 framework integration"""
        print("🎯 Testing SuperClaude Context7 integration...")
        
        # Check if SuperClaude framework files exist
        framework_files = [
            "~/.claude/COMMANDS.md",
            "~/.claude/PERSONAS.md", 
            "~/.claude/ORCHESTRATOR.md",
            "~/.claude/MCP.md"
        ]
        
        missing_files = []
        for file_path in framework_files:
            expanded_path = os.path.expanduser(file_path)
            if not os.path.exists(expanded_path):
                missing_files.append(file_path)
        
        if missing_files:
            print(f"❌ SuperClaude framework files missing: {missing_files}")
            return False
        
        print("✅ SuperClaude Context7 framework ready")
        print("   🔧 Native documentation lookup available")
        print("   📚 Framework patterns and best practices accessible")
        return True
    
    def initialize_mcp_servers(self) -> Dict[str, bool]:
        """Initialize MCP servers and return status"""
        print("🚀 Initializing MCP servers...")
        
        results = {
            'mindsdb': self.test_mindsdb_connection(),
            'context7': self.test_context7_integration()
        }
        
        if all(results.values()):
            print("🎉 All MCP servers initialized successfully")
        else:
            print("⚠️  Some MCP servers failed to initialize")
        
        return results
    
    def get_mindsdb_models(self) -> List[Dict]:
        """Retrieve available MindsDB models for Scout analytics"""
        if not self.test_mindsdb_connection():
            return []
        
        try:
            url = f"{self.credentials['mindsdb']['local_url']}/api/projects/mindsdb/models"
            response = requests.get(url, timeout=15)
            response.raise_for_status()
            
            models = response.json()
            print(f"📊 Found {len(models)} MindsDB models")
            return models
            
        except Exception as e:
            print(f"❌ Failed to retrieve MindsDB models: {e}")
            return []
    
    def create_analytics_pipeline(self, data_source: str = "azure_sql") -> Dict[str, Any]:
        """Create analytics pipeline for Scout data"""
        print(f"📈 Creating analytics pipeline for {data_source}...")
        
        pipeline_config = {
            'name': 'scout_analytics_pipeline',
            'data_source': data_source,
            'models': [
                'customer_lifetime_value_predictor',
                'sales_forecast_model',
                'product_recommendation_engine',
                'store_performance_predictor'
            ],
            'integration': {
                'mindsdb': self.test_mindsdb_connection(),
                'context7': self.test_context7_integration()
            },
            'created_at': datetime.now().isoformat()
        }
        
        return pipeline_config
    
    def generate_integration_report(self) -> Dict[str, Any]:
        """Generate comprehensive MCP integration status report"""
        print("📋 Generating MCP integration report...")
        
        # Test all connections
        server_status = self.initialize_mcp_servers()
        
        # Get MindsDB models if available
        models = self.get_mindsdb_models() if server_status['mindsdb'] else []
        
        # Create analytics pipeline configuration
        pipeline = self.create_analytics_pipeline()
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'system_status': {
                'mcp_servers': server_status,
                'superclaude_framework': server_status.get('context7', False),
                'total_servers': len(server_status),
                'active_servers': sum(server_status.values())
            },
            'mindsdb': {
                'connected': server_status['mindsdb'],
                'api_endpoint': self.credentials['mindsdb']['local_url'],
                'models_available': len(models),
                'models': models[:3] if models else []  # Show first 3 models
            },
            'context7': {
                'connected': server_status['context7'],
                'framework_type': 'SuperClaude native',
                'documentation_lookup_ready': server_status['context7']
            },
            'analytics_pipeline': pipeline,
            'recommendations': self._generate_recommendations(server_status)
        }
        
        return report
    
    def test_mcp_server_health(self) -> Dict[str, bool]:
        """Test MCP server health and availability"""
        print("🧪 Testing MCP servers health...")
        
        mcp_status = {
            'mindsdb_mysql': False,
            'mindsdb_postgres': False,
            'files_available': False
        }
        
        # Check if MCP server files exist
        mysql_server = os.path.join(self.mcp_server_path, "server.mjs")
        pg_server = os.path.join(self.mcp_server_path, "server-pg.mjs")
        mcp_config = os.path.join(self.mcp_server_path, "mcp.json")
        
        if os.path.exists(mysql_server) and os.path.exists(pg_server) and os.path.exists(mcp_config):
            mcp_status['files_available'] = True
            print("✅ MCP server files available")
        else:
            print("❌ MCP server files missing")
        
        # Test MindsDB MySQL connection (port 47335)
        try:
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(3)
            result = sock.connect_ex(('127.0.0.1', 47335))
            sock.close()
            if result == 0:
                mcp_status['mindsdb_mysql'] = True
                print("✅ MindsDB MySQL API accessible on 47335")
            else:
                print("❌ MindsDB MySQL API not accessible on 47335")
        except Exception as e:
            print(f"⚠️  Could not test MindsDB MySQL: {e}")
        
        # Test MindsDB Postgres connection (port 55432)
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(3)
            result = sock.connect_ex(('127.0.0.1', 55432))
            sock.close()
            if result == 0:
                mcp_status['mindsdb_postgres'] = True
                print("✅ MindsDB Postgres API accessible on 55432")
            else:
                print("❌ MindsDB Postgres API not accessible on 55432")
        except Exception as e:
            print(f"⚠️  Could not test MindsDB Postgres: {e}")
        
        return mcp_status
    
    def _generate_recommendations(self, server_status: Dict[str, bool]) -> List[str]:
        """Generate recommendations based on MCP server status"""
        recommendations = []
        
        # Test MCP server health
        mcp_status = self.test_mcp_server_health()
        
        if server_status['mindsdb']:
            recommendations.append("✅ MindsDB ready for predictive analytics implementation")
            recommendations.append("🎯 Recommended: Create sales forecasting model with Azure SQL data")
        else:
            recommendations.append("❌ Fix MindsDB connection before implementing ML workflows")
            if mcp_status['files_available']:
                recommendations.append("💡 MCP servers ready: Deploy MindsDB container with Postgres API")
        
        if server_status['context7']:
            recommendations.append("✅ SuperClaude Context7 ready for documentation lookup")
            recommendations.append("📚 Recommended: Use Context7 for framework patterns and best practices")
        else:
            recommendations.append("❌ Install SuperClaude framework for Context7 capabilities")
        
        if mcp_status['files_available']:
            recommendations.append("🛠️  MCP Integration Ready: MindsDB SQL tools available for Claude Code")
            if mcp_status['mindsdb_mysql'] or mcp_status['mindsdb_postgres']:
                recommendations.append("🔧 Test MCP servers: npm run inspect from ~/mcp-mindsdb")
        
        if all(server_status.values()):
            recommendations.append("🚀 All systems ready for full AI analytics integration")
            recommendations.append("📊 Next steps: Configure automated ML pipelines with real Scout data")
        
        return recommendations

def main():
    parser = argparse.ArgumentParser(
        description='TBWA Project Scout MCP Orchestration Script'
    )
    parser.add_argument(
        '--action',
        choices=['init', 'test', 'analyze', 'report'],
        default='report',
        help='Action to perform (default: report)'
    )
    parser.add_argument(
        '--output',
        help='Output file for results (default: stdout)'
    )
    parser.add_argument(
        '--format',
        choices=['json', 'summary'],
        default='summary',
        help='Output format (default: summary)'
    )
    
    args = parser.parse_args()
    
    # Initialize orchestrator
    orchestrator = MCPOrchestrator()
    
    # Perform requested action
    if args.action == 'init':
        result = orchestrator.initialize_mcp_servers()
        print(f"\n📊 Initialization Results: {result}")
        
    elif args.action == 'test':
        print("🧪 Running MCP server tests...")
        mindsdb_ok = orchestrator.test_mindsdb_connection()
        context7_ok = orchestrator.test_context7_integration()
        
        print(f"\n📊 Test Results:")
        print(f"   MindsDB:  {'✅ PASS' if mindsdb_ok else '❌ FAIL'}")
        print(f"   Context7: {'✅ PASS' if context7_ok else '❌ FAIL'}")
        
    elif args.action == 'analyze':
        models = orchestrator.get_mindsdb_models()
        pipeline = orchestrator.create_analytics_pipeline()
        
        print(f"\n📊 Analysis Results:")
        print(f"   Available Models: {len(models)}")
        print(f"   Pipeline Status: {pipeline['integration']}")
        
    elif args.action == 'report':
        report = orchestrator.generate_integration_report()
        
        if args.format == 'json':
            output = json.dumps(report, indent=2)
        else:
            # Summary format
            output = f"""
🚀 TBWA Project Scout - MCP Integration Report
{'='*50}
Generated: {report['timestamp']}

📊 System Status:
   MCP Servers: {report['system_status']['active_servers']}/{report['system_status']['total_servers']} active
   SuperClaude Framework: {'✅ Active' if report['system_status']['superclaude_framework'] else '❌ Inactive'}

🤖 MindsDB Status:
   Connection: {'✅ Connected' if report['mindsdb']['connected'] else '❌ Disconnected'}
   Endpoint: {report['mindsdb']['api_endpoint']}
   Models: {report['mindsdb']['models_available']} available

🎯 SuperClaude Context7 Status:
   Connection: {'✅ Connected' if report['context7']['connected'] else '❌ Disconnected'}
   Framework Type: {report['context7']['framework_type']}
   Documentation Lookup: {'✅ Ready' if report['context7']['documentation_lookup_ready'] else '❌ Not Ready'}

📈 Analytics Pipeline:
   Pipeline: {report['analytics_pipeline']['name']}
   Models: {len(report['analytics_pipeline']['models'])} configured
   Status: {'✅ Ready' if all(report['analytics_pipeline']['integration'].values()) else '⚠️ Partial'}

💡 Recommendations:
"""
            for rec in report['recommendations']:
                output += f"   {rec}\n"
        
        # Output to file or stdout
        if args.output:
            with open(args.output, 'w') as f:
                f.write(output)
            print(f"📄 Report saved to: {args.output}")
        else:
            print(output)

if __name__ == "__main__":
    main()