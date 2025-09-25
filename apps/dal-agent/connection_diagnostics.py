#!/usr/bin/env python3
"""
Database Connection Diagnostics
Helps identify connection issues with Scout production database
"""

import socket
import telnetlib
from datetime import datetime

def test_network_connectivity():
    """Test basic network connectivity to SQL Server"""

    server = "sqltbwaprojectscoutserver.database.windows.net"
    port = 1433

    print("🔍 Testing network connectivity...")
    print(f"Server: {server}")
    print(f"Port: {port}")

    try:
        # Test basic socket connection
        print("\n1. Testing socket connection...")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)  # 10 second timeout
        result = sock.connect_ex((server, port))

        if result == 0:
            print("✅ Socket connection successful")
            sock.close()
        else:
            print(f"❌ Socket connection failed: Error code {result}")
            print("💡 This usually means:")
            print("  - Firewall is blocking port 1433")
            print("  - Need VPN connection")
            print("  - Server is not accessible from this network")
            return False

    except Exception as e:
        print(f"❌ Socket test failed: {e}")
        return False

    try:
        # Test telnet-like connection
        print("\n2. Testing telnet connection...")
        tn = telnetlib.Telnet()
        tn.open(server, port, timeout=10)
        print("✅ Telnet connection successful")
        tn.close()

    except Exception as e:
        print(f"❌ Telnet test failed: {e}")

    return True

def check_odbc_driver():
    """Check if ODBC driver is available"""

    print("\n🔍 Checking ODBC Driver availability...")

    try:
        import pyodbc
        drivers = pyodbc.drivers()

        sql_server_drivers = [d for d in drivers if 'SQL Server' in d]

        if sql_server_drivers:
            print("✅ SQL Server ODBC drivers found:")
            for driver in sql_server_drivers:
                print(f"  - {driver}")
        else:
            print("❌ No SQL Server ODBC drivers found")
            print("💡 Install ODBC Driver 18 for SQL Server")

        return len(sql_server_drivers) > 0

    except ImportError:
        print("❌ pyodbc not installed")
        print("💡 Install with: pip install pyodbc")
        return False

def test_simplified_connection():
    """Test with most basic connection string"""

    print("\n🔍 Testing simplified database connection...")

    if not check_odbc_driver():
        return False

    if not test_network_connectivity():
        return False

    try:
        import pyodbc

        # Most basic connection string
        conn_str = (
            "DRIVER={ODBC Driver 18 for SQL Server};"
            "SERVER=sqltbwaprojectscoutserver.database.windows.net;"
            "DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod;"
            "UID=TBWA;"
            "PWD=R@nd0mPA$$2025!;"
            "Encrypt=yes;"
            "TrustServerCertificate=yes;"  # Less strict
            "Connection Timeout=60;"
            "Command Timeout=60;"
        )

        print("Attempting database connection...")

        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()

        # Simple test query
        cursor.execute("SELECT GETDATE() as server_time")
        result = cursor.fetchone()

        print(f"✅ Database connection successful!")
        print(f"Server time: {result[0]}")

        cursor.close()
        conn.close()

        return True

    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        print("\n💡 Troubleshooting steps:")
        print("1. Verify you're on the correct network/VPN")
        print("2. Check if IP is whitelisted in Azure SQL firewall")
        print("3. Confirm credentials are correct")
        print("4. Try connecting with SQL Server Management Studio")
        return False

def run_diagnostics():
    """Run complete diagnostic suite"""

    print("🔧 Scout Database Connection Diagnostics")
    print(f"Timestamp: {datetime.now()}")
    print("=" * 50)

    # Step 1: Check ODBC
    odbc_ok = check_odbc_driver()

    # Step 2: Test network
    network_ok = test_network_connectivity()

    # Step 3: Test database connection
    db_ok = test_simplified_connection()

    print("\n" + "=" * 50)
    print("📋 Diagnostic Summary:")
    print(f"ODBC Driver: {'✅' if odbc_ok else '❌'}")
    print(f"Network: {'✅' if network_ok else '❌'}")
    print(f"Database: {'✅' if db_ok else '❌'}")

    if all([odbc_ok, network_ok, db_ok]):
        print("\n🎉 All checks passed! Database connection should work.")
        print("💡 Try running production_export.py again")
    else:
        print("\n⚠️  Some checks failed. Address the issues above first.")
        print("💡 For now, use mock_export.py for testing")

if __name__ == "__main__":
    run_diagnostics()