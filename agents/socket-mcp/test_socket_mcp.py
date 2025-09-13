#!/usr/bin/env python3
"""
Test suite for Socket MCP enhanced features
"""

import asyncio
import json
import tempfile
import os
from pathlib import Path
from datetime import datetime

# Import main components
from main import SocketMCP, LocalArtifactScanner, BuildDiagnosticsEngine
from error_handler import SmartFixGenerator, ErrorReportGenerator
from security_scanner import LocalArtifactSecurityScanner, SecurityAuditor

async def test_error_handling():
    """Test error handling and retry logic"""
    print("🔄 Testing Error Handling & Retry Logic...")
    print("-" * 50)
    
    async with SocketMCP() as mcp:
        # Test network timeout handling
        try:
            # This should trigger retry logic
            result = await mcp.validate_packages(
                packages=['@definitely/not-a-real-package-12345'],
                scan_local=True
            )
            
            print(f"✅ Error handling worked!")
            print(f"📊 Total errors: {result['error_report']['total_errors']}")
            print(f"🔄 Recovery attempts: {result['error_report']['recovery_attempts']}")
            print(f"💡 Suggested fixes: {len(result['suggested_fixes'])}")
            
            for fix in result['suggested_fixes'][:2]:
                print(f"  - {fix['fix_command']}")
                
        except Exception as e:
            print(f"❌ Test failed: {e}")

async def test_local_artifact_scanning():
    """Test local artifact validation"""
    print("\n📦 Testing Local Artifact Scanning...")
    print("-" * 50)
    
    # Create test artifacts
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create fake package.json
        package_json = {
            "name": "test-package",
            "version": "1.0.0",
            "dependencies": {
                "express": "^4.18.0"
            }
        }
        
        package_path = Path(tmpdir) / "package.json"
        with open(package_path, 'w') as f:
            json.dump(package_json, f)
            
        # Test scanning
        scanner = LocalArtifactScanner({})
        result = await scanner.scan_artifact(str(package_path))
        
        print(f"✅ Artifact scanned: {result.artifact_path}")
        print(f"📄 Type: {result.artifact_type.value}")
        print(f"✓ Valid: {result.is_valid}")
        print(f"🔐 Checksum: {result.checksum[:16]}...")
        
        if result.manifest:
            print(f"📋 Manifest: name={result.manifest.get('name')}, version={result.manifest.get('version')}")

async def test_build_diagnostics():
    """Test build failure diagnostics"""
    print("\n🔧 Testing Build Failure Diagnostics...")
    print("-" * 50)
    
    # Sample error messages
    error_messages = [
        "npm ERR! 404 Not Found - GET https://registry.npmjs.org/@types/not-found - Not found",
        "Module not found: Error: Can't resolve 'express' in '/src/app'",
        "ETIMEDOUT network request to https://registry.npmjs.org/lodash failed",
        "java.lang.ClassNotFoundException: com.example.MyClass"
    ]
    
    diagnostics = BuildDiagnosticsEngine({
        'build_diagnostics': {
            'common_errors': []
        }
    })
    
    for error_msg in error_messages:
        report = await diagnostics.diagnose_error(error_msg)
        print(f"\n🔍 Error: {error_msg[:50]}...")
        print(f"📁 Category: {report.category.value}")
        if report.suggested_fix:
            print(f"💡 Fix: {report.suggested_fix}")

async def test_fix_suggestions():
    """Test smart fix generation"""
    print("\n💡 Testing Smart Fix Suggestions...")
    print("-" * 50)
    
    fix_generator = SmartFixGenerator()
    
    # Test various error scenarios
    test_cases = [
        {
            'error': "ETIMEDOUT network request to https://registry.npmjs.org failed",
            'context': {'package_manager': 'npm'}
        },
        {
            'error': "Could not find artifact com.example:mylib:1.0.0",
            'context': {'build_tool': 'maven'}
        },
        {
            'error': "No module named 'requests'",
            'context': {'package_manager': 'pip'}
        }
    ]
    
    for test in test_cases:
        fixes = await fix_generator.generate_fixes(test['error'], test['context'])
        print(f"\n🔍 Error: {test['error']}")
        print(f"🛠️ Top fixes:")
        
        for i, fix in enumerate(fixes[:3], 1):
            print(f"  {i}. {fix.command}")
            print(f"     Confidence: {fix.confidence}")

async def test_security_scanning():
    """Test security vulnerability scanning"""
    print("\n🔒 Testing Security Scanning...")
    print("-" * 50)
    
    scanner = LocalArtifactSecurityScanner({})
    
    # Test with a known package
    test_manifest = {
        'name': 'lodash',
        'version': '4.17.20'  # Known to have vulnerabilities
    }
    
    # Create test artifact
    with tempfile.TemporaryDirectory() as tmpdir:
        artifact_path = Path(tmpdir) / "package.json"
        with open(artifact_path, 'w') as f:
            json.dump(test_manifest, f)
            
        result = await scanner.scan_artifact(str(artifact_path), test_manifest)
        
        print(f"✅ Security scan completed")
        print(f"📊 Risk score: {result.risk_score}/10")
        print(f"🔍 Vulnerabilities found: {len(result.vulnerabilities)}")
        print(f"🛡️ Scan engines used: {', '.join(result.scan_engines_used)}")
        
        if result.recommendations:
            print(f"\n📋 Recommendations:")
            for rec in result.recommendations[:2]:
                print(f"  - {rec}")

async def test_error_report_generation():
    """Test comprehensive error report generation"""
    print("\n📊 Testing Error Report Generation...")
    print("-" * 50)
    
    report_generator = ErrorReportGenerator()
    
    # Simulate multiple errors
    errors = [
        {
            'category': 'network_error',
            'message': 'ETIMEDOUT connecting to registry',
            'timestamp': datetime.now(),
            'resolved': False
        },
        {
            'category': 'network_error', 
            'message': 'ECONNREFUSED registry.npmjs.org',
            'timestamp': datetime.now(),
            'resolved': False
        },
        {
            'category': 'missing_dependency',
            'message': "Module not found: 'express'",
            'timestamp': datetime.now(),
            'resolved': True
        }
    ]
    
    report = await report_generator.generate_report(errors, {'package_manager': 'npm'})
    
    print(f"📈 Report Summary:")
    print(f"  Total errors: {report['summary']['total_errors']}")
    print(f"  Resolved: {report['summary']['resolved_errors']}")
    print(f"  Root cause: {report['root_cause_analysis']['likely_root_cause']}")
    
    if report['action_plan']:
        print(f"\n🎯 Action Plan:")
        for step in report['action_plan']:
            print(f"  {step['step']}. {step['primary_fix']['command']}")

async def main():
    """Run all tests"""
    print("🚀 Socket MCP Enhanced Features Test Suite")
    print("=" * 50)
    
    # Run tests
    await test_error_handling()
    await test_local_artifact_scanning()
    await test_build_diagnostics()
    await test_fix_suggestions()
    await test_security_scanning()
    await test_error_report_generation()
    
    print("\n✅ All tests completed!")
    print("=" * 50)

if __name__ == '__main__':
    asyncio.run(main())