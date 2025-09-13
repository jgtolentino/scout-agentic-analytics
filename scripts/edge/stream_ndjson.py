#!/usr/bin/env python3
"""
Real-time NDJSON streaming to Scout platform
Supports both file input and live streaming from stdin/pipes
"""

import os
import sys
import time
import json
import requests
from typing import Iterator, Union, TextIO

# Configuration from environment
EDGE_TOKEN = os.environ["SUPABASE_EDGE_TOKEN"]
PROJECT_REF = os.environ["PROJECT_REF"]
DEVICE_ID = os.environ.get("DEVICE_ID", "pi-05")
URL = f"https://{PROJECT_REF}.functions.supabase.co/ingest-stream"

def iter_lines(src: Union[str, TextIO]) -> Iterator[str]:
    """Iterate over lines from file or stdin"""
    if src == "-" or src == sys.stdin:
        print(f"📡 Streaming from stdin (device: {DEVICE_ID})", file=sys.stderr)
        for line in sys.stdin:
            yield line
    elif hasattr(src, 'read'):  # File-like object
        for line in src:
            yield line
    else:  # File path
        print(f"📄 Streaming from file: {src} (device: {DEVICE_ID})", file=sys.stderr)
        with open(src, "r") as f:
            for line in f:
                yield line

def stream_generator(src: Union[str, TextIO], throttle_ms: int = 0) -> Iterator[bytes]:
    """Generate bytes for streaming request"""
    lines_sent = 0
    for ln in iter_lines(src):
        if not ln.strip():
            continue
        
        # Validate JSON before sending
        try:
            json.loads(ln.strip())
        except json.JSONDecodeError:
            print(f"⚠️  Skipping invalid JSON: {ln[:50]}...", file=sys.stderr)
            continue
        
        yield ln.encode("utf-8")
        lines_sent += 1
        
        # Optional throttling for high-volume streams
        if throttle_ms > 0:
            time.sleep(throttle_ms / 1000.0)
        
        # Progress indicator for large files
        if lines_sent % 100 == 0:
            print(f"📊 Streamed {lines_sent} lines...", file=sys.stderr)

def stream_to_scout(src: Union[str, TextIO], throttle_ms: int = 0) -> dict:
    """Stream NDJSON data to Scout platform"""
    headers = {
        "Authorization": f"Bearer {EDGE_TOKEN}",
        "Content-Type": "application/x-ndjson",
        "x-device-id": DEVICE_ID
    }
    
    print(f"🚀 Starting stream to {URL}", file=sys.stderr)
    print(f"📱 Device ID: {DEVICE_ID}", file=sys.stderr)
    
    try:
        response = requests.post(
            URL, 
            headers=headers, 
            data=stream_generator(src, throttle_ms),
            timeout=300,  # 5 minute timeout
            stream=False
        )
        
        result = response.json()
        
        if response.status_code == 200 and result.get('success'):
            print(f"✅ Stream successful!", file=sys.stderr)
            print(f"📊 Lines: {result.get('lines_seen', 0)}, Inserted: {result.get('inserted', 0)}", file=sys.stderr)
            if result.get('errors', 0) > 0:
                print(f"⚠️  Parse errors: {result['errors']}", file=sys.stderr)
        else:
            print(f"❌ Stream failed: HTTP {response.status_code}", file=sys.stderr)
            print(f"Error: {result.get('error', 'Unknown error')}", file=sys.stderr)
        
        return result
        
    except requests.exceptions.RequestException as e:
        error_result = {"success": False, "error": f"Network error: {str(e)}"}
        print(f"❌ Network error: {e}", file=sys.stderr)
        return error_result
    except json.JSONDecodeError:
        error_result = {"success": False, "error": "Invalid JSON response from server"}
        print(f"❌ Invalid response from server", file=sys.stderr)
        return error_result

def main():
    """Main CLI interface"""
    if len(sys.argv) < 2:
        print("Usage: stream_ndjson.py <file_or_stdin> [throttle_ms]", file=sys.stderr)
        print("", file=sys.stderr)
        print("Examples:", file=sys.stderr)
        print("  # Stream from file", file=sys.stderr)
        print("  stream_ndjson.py transactions.jsonl", file=sys.stderr)
        print("", file=sys.stderr)
        print("  # Stream from stdin", file=sys.stderr)
        print("  cat data.jsonl | stream_ndjson.py -", file=sys.stderr)
        print("", file=sys.stderr)
        print("  # Real-time tail", file=sys.stderr)
        print("  tail -F /var/log/transactions.jsonl | stream_ndjson.py -", file=sys.stderr)
        print("", file=sys.stderr)
        print("  # With throttling (10ms between lines)", file=sys.stderr)
        print("  stream_ndjson.py data.jsonl 10", file=sys.stderr)
        sys.exit(1)
    
    src = sys.argv[1]
    throttle_ms = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    
    # Check environment
    missing_vars = []
    if not EDGE_TOKEN:
        missing_vars.append("SUPABASE_EDGE_TOKEN")
    if not PROJECT_REF:
        missing_vars.append("PROJECT_REF")
    
    if missing_vars:
        print(f"❌ Missing required environment variables: {', '.join(missing_vars)}", file=sys.stderr)
        sys.exit(1)
    
    # Execute stream
    result = stream_to_scout(src, throttle_ms)
    
    # Output result as JSON for programmatic use
    print(json.dumps(result, indent=2))
    
    # Exit with appropriate code
    sys.exit(0 if result.get('success') else 1)

if __name__ == "__main__":
    main()