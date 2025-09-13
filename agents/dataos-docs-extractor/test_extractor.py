#!/usr/bin/env python3
"""
Test script for DataOS Documentation Extractor
Demonstrates all major features
"""

import asyncio
import json
from datetime import datetime
from main import (
    DataOSDocsExtractor,
    ExtractionConfig,
    ExtractionMethod,
    OutputFormat,
    DiffMode,
    DocumentExtractor,
    DiffEngine
)

async def test_extraction():
    """Test documentation extraction"""
    print("🔎 Testing Documentation Extraction...")
    print("-" * 50)
    
    # Test with a small documentation site
    config = ExtractionConfig(
        source_url="https://example.com",  # Replace with actual docs URL
        output_format=OutputFormat.MARKDOWN,
        extraction_method=ExtractionMethod.STATIC,
        max_depth=2,
        max_pages=10
    )
    
    extractor = DocumentExtractor(config)
    
    try:
        archive_path, metadata = await extractor.extract()
        print(f"✅ Extraction successful!")
        print(f"📁 Archive: {archive_path}")
        print(f"📄 Pages extracted: {metadata.total_pages}")
        print(f"⏱️  Time: {metadata.extraction_time:.2f}s")
        print(f"🔐 Checksum: {metadata.checksum[:16]}...")
        return archive_path
    except Exception as e:
        print(f"❌ Extraction failed: {e}")
        return None

async def test_diff(archive1: str, archive2: str):
    """Test diff functionality"""
    print("\n🧠 Testing Diff Engine...")
    print("-" * 50)
    
    diff_engine = DiffEngine()
    
    try:
        # Test semantic diff
        print("📝 Computing semantic diff...")
        result = await diff_engine.compute_diff(
            archive1,
            archive2,
            DiffMode.SEMANTIC
        )
        
        print(f"✅ Diff completed!")
        print(f"➕ Added: {result.added_sections} sections")
        print(f"➖ Removed: {result.removed_sections} sections")
        print(f"📝 Modified: {result.modified_sections} sections")
        print(f"📊 Total changes: {result.total_changes}")
        
        if result.semantic_diff_path:
            print(f"📄 Diff report: {result.semantic_diff_path}")
            
    except Exception as e:
        print(f"❌ Diff failed: {e}")

async def test_cli_commands():
    """Test CLI command execution"""
    print("\n🔧 Testing CLI Commands...")
    print("-" * 50)
    
    extractor = DataOSDocsExtractor()
    
    # Mock command line arguments
    class Args:
        pass
    
    # Test extract command
    print("1️⃣ Testing extract command...")
    args = Args()
    args.source = "https://example.com"
    args.format = "markdown"
    args.method = "static"
    args.auth = None
    
    try:
        result = await extractor.extract(args)
        print(f"✅ Extract command: {result['status']}")
    except Exception as e:
        print(f"❌ Extract command failed: {e}")
    
    # Test analyze command
    print("\n2️⃣ Testing analyze command...")
    args = Args()
    args.archive = "/dataos-archives/test"  # Use a test archive
    
    try:
        # Create a test archive first
        import os
        os.makedirs(args.archive, exist_ok=True)
        
        # Create test metadata
        metadata = {
            "source_url": "https://example.com",
            "timestamp": datetime.now().isoformat(),
            "total_pages": 10,
            "extraction_time": 5.5,
            "format": "markdown"
        }
        
        with open(f"{args.archive}/metadata.json", 'w') as f:
            json.dump(metadata, f)
            
        result = await extractor.analyze(args)
        print(f"✅ Analyze command: {result['status']}")
    except Exception as e:
        print(f"❌ Analyze command failed: {e}")

def test_api_models():
    """Test API request/response models"""
    print("\n📡 Testing API Models...")
    print("-" * 50)
    
    try:
        from api import ExtractionRequest, DiffRequest, ScheduleRequest
        
        # Test extraction request
        extraction_req = ExtractionRequest(
            source_url="https://dataos.info",
            output_format="markdown",
            extraction_method="hybrid"
        )
        print(f"✅ ExtractionRequest: {extraction_req.source_url}")
        
        # Test diff request
        diff_req = DiffRequest(
            archive1="/dataos-archives/20240807",
            archive2="/dataos-archives/20240808",
            mode="both"
        )
        print(f"✅ DiffRequest: {diff_req.mode}")
        
        # Test schedule request
        schedule_req = ScheduleRequest(
            source_url="https://dataos.info",
            cron="0 2 * * *",
            output_format="markdown"
        )
        print(f"✅ ScheduleRequest: {schedule_req.cron}")
        
    except Exception as e:
        print(f"❌ API model test failed: {e}")

async def test_notifications():
    """Test notification system"""
    print("\n🔔 Testing Notifications...")
    print("-" * 50)
    
    from main import NotificationService
    
    config = {
        "enabled": True,
        "channels": [
            {
                "type": "webhook",
                "url": "https://httpbin.org/post"  # Test endpoint
            }
        ]
    }
    
    service = NotificationService(config)
    
    try:
        await service.notify("test_event", {
            "message": "Test notification",
            "timestamp": datetime.now().isoformat()
        })
        print("✅ Notification sent successfully")
    except Exception as e:
        print(f"❌ Notification failed: {e}")

async def main():
    """Run all tests"""
    print("🚀 DataOS Documentation Extractor Test Suite")
    print("=" * 50)
    
    # Test extraction
    archive1 = await test_extraction()
    
    # Create a second archive for diff testing
    if archive1:
        # Simulate changes by creating another archive
        archive2 = archive1  # In real test, this would be different
        await test_diff(archive1, archive2)
    
    # Test CLI commands
    await test_cli_commands()
    
    # Test API models
    test_api_models()
    
    # Test notifications
    await test_notifications()
    
    print("\n✅ All tests completed!")
    print("=" * 50)

if __name__ == "__main__":
    asyncio.run(main())