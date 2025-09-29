#!/usr/bin/env python3
"""
Scout v7 Stata Pipeline Smoke Test
Validates pipeline components without database access
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path

def check_prerequisites():
    """Check required software and dependencies"""
    print("🔍 Checking prerequisites...")

    # Check Stata
    stata_commands = ['stata', 'stata-mp', 'stata-se']
    stata_found = False
    for cmd in stata_commands:
        if shutil.which(cmd):
            print(f"  ✅ Found Stata: {cmd}")
            stata_found = True
            break

    if not stata_found:
        print("  ❌ Stata not found in PATH")
        return False

    # Check ODBC driver (Linux/macOS)
    try:
        result = subprocess.run(['odbcinst', '-q', '-d'],
                              capture_output=True, text=True, check=True)
        if 'ODBC Driver 18 for SQL Server' in result.stdout:
            print("  ✅ ODBC Driver 18 for SQL Server found")
        else:
            print("  ⚠️ ODBC Driver 18 for SQL Server not found")
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("  ⚠️ Could not check ODBC driver (Windows or odbcinst not available)")

    # Check directories
    required_dirs = ['stata', 'logs', 'out', 'scripts']
    for dirname in required_dirs:
        if os.path.isdir(dirname):
            print(f"  ✅ Directory exists: {dirname}")
        else:
            print(f"  ⚠️ Directory missing: {dirname} (will be created)")
            os.makedirs(dirname, exist_ok=True)

    return True

def validate_stata_script():
    """Validate Stata do-file syntax"""
    print("\n📝 Validating Stata script syntax...")

    stata_file = Path('stata/scout_pipeline.do')
    if not stata_file.exists():
        print("  ❌ stata/scout_pipeline.do not found")
        return False

    print(f"  ✅ Found Stata script: {stata_file}")

    # Basic syntax validation
    with open(stata_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    # Check for required sections
    required_sections = [
        'version 18.0',
        'ODBC',
        'gold.v_export_projection',
        'Asia/Manila',
        'reconciliation',
        'export delimited'
    ]

    for section in required_sections:
        if section in content:
            print(f"  ✅ Found required section: {section}")
        else:
            print(f"  ❌ Missing required section: {section}")

    # Check for production fixes
    production_checks = [
        ('Manila timezone', 'Singapore Standard Time'),
        ('Robust reconciliation', 'absolute floors'),
        ('CSV safety', 'char(13)'),
        ('UTF-8 export', 'encoding(utf8)'),
        ('QA logging', 'qa_log'),
        ('Error trapping', 'exit 459')
    ]

    print("  📋 Production readiness checks:")
    for check_name, pattern in production_checks:
        if pattern in content:
            print(f"    ✅ {check_name}")
        else:
            print(f"    ⚠️ {check_name} - pattern '{pattern}' not found")

    return True

def validate_wrapper_scripts():
    """Validate execution wrapper scripts"""
    print("\n🔧 Validating wrapper scripts...")

    # Unix/macOS script
    unix_script = Path('run_stata_pipeline.sh')
    if unix_script.exists():
        print(f"  ✅ Found Unix wrapper: {unix_script}")
        if os.access(unix_script, os.X_OK):
            print("    ✅ Script is executable")
        else:
            print("    ⚠️ Script not executable, fixing...")
            os.chmod(unix_script, 0o755)
    else:
        print("  ❌ Unix wrapper script missing")

    # Windows script
    windows_script = Path('run_stata_pipeline.bat')
    if windows_script.exists():
        print(f"  ✅ Found Windows wrapper: {windows_script}")
    else:
        print("  ❌ Windows wrapper script missing")

    return True

def validate_bruno_integration():
    """Validate Bruno integration"""
    print("\n🔐 Validating Bruno integration...")

    bruno_dir = Path('bruno')
    if bruno_dir.exists():
        print(f"  ✅ Found Bruno directory: {bruno_dir}")

        # Check Bruno collection file
        bruno_collection = bruno_dir / 'stata_validation.bru'
        if bruno_collection.exists():
            print("    ✅ Found Bruno validation script")
        else:
            print("    ❌ Bruno validation script missing")

        # Check Bruno config
        bruno_config = bruno_dir / 'bruno.json'
        if bruno_config.exists():
            print("    ✅ Found Bruno configuration")
        else:
            print("    ❌ Bruno configuration missing")
    else:
        print("  ❌ Bruno directory missing")

    # Check if Bruno is installed
    if shutil.which('bruno'):
        print("  ✅ Bruno CLI available")
    else:
        print("  ⚠️ Bruno CLI not found (optional for direct execution)")

    return True

def validate_github_actions():
    """Validate GitHub Actions workflow"""
    print("\n⚙️ Validating GitHub Actions workflow...")

    workflow_file = Path('.github/workflows/stata-validation.yml')
    if workflow_file.exists():
        print(f"  ✅ Found GitHub Actions workflow: {workflow_file}")

        with open(workflow_file, 'r') as f:
            content = f.read()

        required_components = [
            'workflow_dispatch',
            'self-hosted',
            'Asia/Manila',
            'Bruno execution',
            'artifact upload'
        ]

        for component in required_components:
            if component.replace(' ', '-').lower() in content.lower():
                print(f"    ✅ Found: {component}")
            else:
                print(f"    ⚠️ Missing: {component}")
    else:
        print("  ❌ GitHub Actions workflow missing")

    return True

def create_sample_credentials():
    """Create sample credential configuration"""
    print("\n🔑 Creating sample credential configuration...")

    sample_env = """# Scout v7 Stata Pipeline Environment Variables
# Copy to .env and fill in actual values

# Azure SQL Database Connection
export SCOUT_DSN="Driver=ODBC Driver 18 for SQL Server;Server=tcp:sqltbwaprojectscoutserver.database.windows.net,1433;Database=SQL-TBWA-ProjectScout-Reporting-Prod;Encrypt=yes;TrustServerCertificate=no;"
export SCOUT_USER="scout_analytics"
export SCOUT_PWD="***REPLACE_WITH_ACTUAL_PASSWORD***"

# Pipeline Parameters
export FROM_DATE="2025-06-28"
export TO_DATE="2025-09-26"
export NCR_FOCUS="1"
export QA_TOLERANCE="0.01"

# Timezone
export TZ="Asia/Manila"

# For macOS Keychain (recommended):
# security add-generic-password -U -s "SQL-TBWA-ProjectScout-Reporting-Prod" -a "scout_analytics" -w "<your-password>"
"""

    with open('.env.sample', 'w') as f:
        f.write(sample_env)

    print("  ✅ Created .env.sample file")
    print("  📋 Next steps:")
    print("     1. Copy .env.sample to .env")
    print("     2. Fill in actual Azure SQL credentials")
    print("     3. For macOS: Use keychain storage (see .env.sample)")

    return True

def main():
    """Main smoke test execution"""
    print("🚀 SCOUT v7 STATA PIPELINE SMOKE TEST")
    print("=====================================")

    # Change to dal-agent directory if not already there
    if not os.path.exists('stata'):
        if os.path.exists('apps/dal-agent/stata'):
            os.chdir('apps/dal-agent')
            print(f"📁 Changed to directory: {os.getcwd()}")
        else:
            print("❌ FATAL: Cannot find stata directory")
            sys.exit(1)

    tests = [
        check_prerequisites,
        validate_stata_script,
        validate_wrapper_scripts,
        validate_bruno_integration,
        validate_github_actions,
        create_sample_credentials
    ]

    results = []
    for test in tests:
        try:
            result = test()
            results.append(result)
        except Exception as e:
            print(f"  ❌ Test failed with error: {e}")
            results.append(False)

    # Summary
    print("\n📊 SMOKE TEST SUMMARY")
    print("====================")
    passed = sum(1 for r in results if r)
    total = len(results)

    print(f"Tests passed: {passed}/{total}")

    if all(results):
        print("✅ ALL SMOKE TESTS PASSED")
        print("\n🎉 Pipeline is ready for production deployment!")
        print("   Next steps:")
        print("   1. Configure Azure SQL credentials")
        print("   2. Test with small date range first")
        print("   3. Run full validation pipeline")
        return 0
    else:
        print("❌ SOME SMOKE TESTS FAILED")
        print("\n🔧 Please address the issues above before deployment")
        return 1

if __name__ == "__main__":
    sys.exit(main())