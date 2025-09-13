#!/usr/bin/env python3
"""
Schema Guard - Namespace Compliance Enforcement
Validates and fixes namespace violations across repository
"""

import os
import re
import yaml
import json
from pathlib import Path
from typing import Dict, List, Tuple
from dataclasses import dataclass

@dataclass
class NamespaceViolation:
    file_path: str
    line_number: int
    violation_type: str
    current_name: str
    suggested_fix: str
    confidence: float

@dataclass
class ComplianceReport:
    total_files_scanned: int
    violations_found: int
    violations_fixed: int
    namespaces_validated: Dict[str, int]
    suggestions: List[NamespaceViolation]

class SchemaGuard:
    def __init__(self, repo_root: str, dry_run: bool = True):
        self.repo_root = Path(repo_root)
        self.dry_run = dry_run
        self.schema_registry = self._load_schema_registry()
        self.violations: List[NamespaceViolation] = []
        
    def _load_schema_registry(self) -> Dict:
        """Load schema registry configuration"""
        try:
            with open(self.repo_root / 'SCHEMA_REGISTRY.yaml', 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            print("⚠️  SCHEMA_REGISTRY.yaml not found, using default rules")
            return self._get_default_rules()
    
    def _get_default_rules(self) -> Dict:
        """Default schema registry rules"""
        return {
            'validation_rules': {
                'table_naming': '^(scout|ces|neural_databank)_[a-z_]+$',
                'function_naming': '^[a-z_]+_(scout|ces|neural)$',
                'api_naming': '^/(api/v[0-9]+|internal)/(scout|ces|neural|lakehouse|mcp)/'
            },
            'namespaces': {
                'scout': {'description': 'Core Scout dashboard data'},
                'ces': {'description': 'Creative Effectiveness Score system'},
                'neural_databank': {'description': 'AI/ML models and predictions'}
            }
        }
    
    def validate_migration_files(self) -> List[NamespaceViolation]:
        """Validate Supabase migration files for namespace compliance"""
        violations = []
        migrations_path = self.repo_root / 'supabase' / 'migrations'
        
        if not migrations_path.exists():
            print("ℹ️  No migrations directory found")
            return violations
        
        table_pattern = self.schema_registry['validation_rules']['table_naming']
        function_pattern = self.schema_registry['validation_rules']['function_naming']
        
        for migration_file in migrations_path.glob('*.sql'):
            try:
                with open(migration_file, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
            except UnicodeDecodeError:
                try:
                    with open(migration_file, 'r', encoding='latin-1') as f:
                        lines = f.readlines()
                except UnicodeDecodeError:
                    print(f"⚠️ Skipping {migration_file} due to encoding issues")
                    continue
            
            for line_num, line in enumerate(lines, 1):
                # Check table naming
                table_match = re.search(r'CREATE TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:[a-zA-Z_]+\.)?([a-zA-Z_]+)', line, re.IGNORECASE)
                if table_match:
                    table_name = table_match.group(1)
                    if not re.match(table_pattern, table_name):
                        suggested_fix = self._suggest_table_fix(table_name)
                        violations.append(NamespaceViolation(
                            file_path=str(migration_file),
                            line_number=line_num,
                            violation_type='table_naming',
                            current_name=table_name,
                            suggested_fix=suggested_fix,
                            confidence=0.8
                        ))
                
                # Check function naming
                function_match = re.search(r'CREATE.*FUNCTION\s+(?:[a-zA-Z_]+\.)?([a-zA-Z_]+)', line, re.IGNORECASE)
                if function_match:
                    function_name = function_match.group(1)
                    if not re.match(function_pattern, function_name):
                        suggested_fix = self._suggest_function_fix(function_name)
                        violations.append(NamespaceViolation(
                            file_path=str(migration_file),
                            line_number=line_num,
                            violation_type='function_naming',
                            current_name=function_name,
                            suggested_fix=suggested_fix,
                            confidence=0.7
                        ))
        
        return violations
    
    def validate_edge_functions(self) -> List[NamespaceViolation]:
        """Validate Edge Function files for namespace compliance"""
        violations = []
        functions_path = self.repo_root / 'supabase' / 'functions'
        
        if not functions_path.exists():
            print("ℹ️  No Edge Functions directory found")
            return violations
        
        for function_dir in functions_path.iterdir():
            if function_dir.is_dir():
                function_name = function_dir.name
                
                # Check function directory naming
                if not self._is_valid_edge_function_name(function_name):
                    suggested_fix = self._suggest_edge_function_fix(function_name)
                    violations.append(NamespaceViolation(
                        file_path=str(function_dir),
                        line_number=0,
                        violation_type='edge_function_naming',
                        current_name=function_name,
                        suggested_fix=suggested_fix,
                        confidence=0.9
                    ))
        
        return violations
    
    def validate_api_routes(self) -> List[NamespaceViolation]:
        """Validate API route patterns for namespace compliance"""
        violations = []
        api_pattern = self.schema_registry['validation_rules']['api_naming']
        
        # Check Next.js API routes
        api_routes_path = self.repo_root / 'apps' / 'web' / 'src' / 'app' / 'api'
        if api_routes_path.exists():
            for route_file in api_routes_path.rglob('*.ts'):
                route_path = str(route_file.relative_to(api_routes_path))
                route_url = f"/api/{route_path.replace('/route.ts', '').replace('/page.ts', '')}"
                
                if not re.match(api_pattern, route_url):
                    suggested_fix = self._suggest_api_route_fix(route_url)
                    violations.append(NamespaceViolation(
                        file_path=str(route_file),
                        line_number=0,
                        violation_type='api_route_naming',
                        current_name=route_url,
                        suggested_fix=suggested_fix,
                        confidence=0.6
                    ))
        
        return violations
    
    def _suggest_table_fix(self, table_name: str) -> str:
        """Suggest proper table naming fix"""
        # Analyze table name to suggest appropriate namespace
        if 'campaign' in table_name or 'metric' in table_name:
            if 'ces' not in table_name.lower():
                return f"scout_{table_name}" if not table_name.startswith('scout_') else table_name
        elif 'neural' in table_name or 'model' in table_name or 'predict' in table_name:
            return f"neural_databank_{table_name}" if not table_name.startswith('neural_databank_') else table_name
        elif 'ces' in table_name or 'creative' in table_name:
            return f"ces_{table_name}" if not table_name.startswith('ces_') else table_name
        else:
            return f"scout_{table_name}"
    
    def _suggest_function_fix(self, function_name: str) -> str:
        """Suggest proper function naming fix"""
        if function_name.endswith('_scout') or function_name.endswith('_ces') or function_name.endswith('_neural'):
            return function_name
        
        # Analyze function name to suggest appropriate suffix
        if 'neural' in function_name or 'predict' in function_name or 'model' in function_name:
            return f"{function_name}_neural"
        elif 'ces' in function_name or 'creative' in function_name:
            return f"{function_name}_ces"
        else:
            return f"{function_name}_scout"
    
    def _suggest_edge_function_fix(self, function_name: str) -> str:
        """Suggest proper Edge Function naming fix"""
        if function_name.startswith(('scout-', 'ces-', 'neural-')):
            return function_name
        
        # Suggest appropriate prefix
        if 'neural' in function_name or 'predict' in function_name:
            return f"neural-{function_name}"
        elif 'ces' in function_name or 'creative' in function_name:
            return f"ces-{function_name}"
        else:
            return f"scout-{function_name}"
    
    def _suggest_api_route_fix(self, route_url: str) -> str:
        """Suggest proper API route naming fix"""
        # Extract version and endpoint
        parts = route_url.strip('/').split('/')
        if len(parts) >= 2:
            if parts[0] == 'api' and parts[1].startswith('v'):
                # Already versioned API
                if len(parts) >= 3:
                    endpoint = parts[2]
                    if endpoint not in ['scout', 'ces', 'neural']:
                        # Suggest appropriate namespace
                        if 'neural' in endpoint or 'predict' in endpoint:
                            return f"/api/{parts[1]}/neural/{'/'.join(parts[2:])}"
                        elif 'ces' in endpoint:
                            return f"/api/{parts[1]}/ces/{'/'.join(parts[2:])}"
                        else:
                            return f"/api/{parts[1]}/scout/{'/'.join(parts[2:])}"
            else:
                # Not properly versioned
                return f"/api/v1/scout/{'/'.join(parts[1:])}"
        
        return route_url
    
    def _is_valid_edge_function_name(self, function_name: str) -> bool:
        """Check if Edge Function name follows namespace conventions"""
        valid_prefixes = ['scout-', 'ces-', 'neural-']
        return any(function_name.startswith(prefix) for prefix in valid_prefixes)
    
    def generate_compliance_report(self) -> ComplianceReport:
        """Generate comprehensive compliance report"""
        print("🔍 Scanning for namespace violations...")
        
        migration_violations = self.validate_migration_files()
        edge_function_violations = self.validate_edge_functions()
        api_violations = self.validate_api_routes()
        
        all_violations = migration_violations + edge_function_violations + api_violations
        
        # Count violations by namespace
        namespace_counts = {}
        for violation in all_violations:
            violation_type = violation.violation_type
            namespace_counts[violation_type] = namespace_counts.get(violation_type, 0) + 1
        
        files_scanned = (
            len(list((self.repo_root / 'supabase' / 'migrations').glob('*.sql'))) if 
            (self.repo_root / 'supabase' / 'migrations').exists() else 0
        ) + (
            len(list((self.repo_root / 'supabase' / 'functions').iterdir())) if 
            (self.repo_root / 'supabase' / 'functions').exists() else 0
        )
        
        return ComplianceReport(
            total_files_scanned=files_scanned,
            violations_found=len(all_violations),
            violations_fixed=0,  # Will be updated during fix application
            namespaces_validated=namespace_counts,
            suggestions=all_violations
        )
    
    def apply_fixes(self) -> int:
        """Apply suggested fixes (if not in dry-run mode)"""
        if self.dry_run:
            print("🔍 Dry-run mode: No changes will be applied")
            return 0
        
        print("🔧 Applying namespace compliance fixes...")
        fixes_applied = 0
        
        # Group violations by file for efficient processing
        files_to_fix = {}
        for violation in self.violations:
            if violation.file_path not in files_to_fix:
                files_to_fix[violation.file_path] = []
            files_to_fix[violation.file_path].append(violation)
        
        for file_path, violations in files_to_fix.items():
            if self._apply_file_fixes(file_path, violations):
                fixes_applied += len(violations)
        
        return fixes_applied
    
    def _apply_file_fixes(self, file_path: str, violations: List[NamespaceViolation]) -> bool:
        """Apply fixes to a specific file"""
        try:
            with open(file_path, 'r') as f:
                lines = f.readlines()
            
            # Sort violations by line number in reverse order to avoid offset issues
            violations.sort(key=lambda v: v.line_number, reverse=True)
            
            for violation in violations:
                if violation.line_number > 0:  # Line-based fix
                    line_idx = violation.line_number - 1
                    if line_idx < len(lines):
                        lines[line_idx] = lines[line_idx].replace(
                            violation.current_name, 
                            violation.suggested_fix
                        )
            
            # Write back the fixed content
            with open(file_path, 'w') as f:
                f.writelines(lines)
            
            return True
        except Exception as e:
            print(f"❌ Error applying fixes to {file_path}: {e}")
            return False
    
    def export_compliance_report(self, output_file: str = 'namespace_compliance_report.json'):
        """Export compliance report to JSON"""
        report = self.generate_compliance_report()
        self.violations = report.suggestions  # Store for potential fixing
        
        # Convert to serializable format
        report_data = {
            'total_files_scanned': report.total_files_scanned,
            'violations_found': report.violations_found,
            'violations_fixed': report.violations_fixed,
            'namespaces_validated': report.namespaces_validated,
            'suggestions': [
                {
                    'file_path': v.file_path,
                    'line_number': v.line_number,
                    'violation_type': v.violation_type,
                    'current_name': v.current_name,
                    'suggested_fix': v.suggested_fix,
                    'confidence': v.confidence
                } for v in report.suggestions
            ],
            'timestamp': '2025-09-12T11:30:00Z'
        }
        
        output_path = self.repo_root / output_file
        with open(output_path, 'w') as f:
            json.dump(report_data, f, indent=2)
        
        print(f"📊 Namespace compliance report exported to: {output_path}")
        return report_data

def main():
    """Main execution function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Schema Guard - Namespace Compliance Tool')
    parser.add_argument('--fix', action='store_true', help='Apply suggested fixes (not dry-run)')
    parser.add_argument('--repo-root', default='.', help='Repository root directory')
    
    args = parser.parse_args()
    
    guard = SchemaGuard(args.repo_root, dry_run=not args.fix)
    
    print("🛡️  Schema Guard - Namespace Compliance Validation")
    report = guard.export_compliance_report()
    
    print(f"\n📈 Compliance Summary:")
    print(f"   - Files scanned: {report['total_files_scanned']}")
    print(f"   - Violations found: {report['violations_found']}")
    print(f"   - Violation types: {list(report['namespaces_validated'].keys())}")
    
    if args.fix and report['violations_found'] > 0:
        fixes_applied = guard.apply_fixes()
        print(f"   - Fixes applied: {fixes_applied}")
    elif report['violations_found'] > 0:
        print("   - Use --fix flag to apply suggested fixes")
        print("\n⚠️  Top namespace violations:")
        for suggestion in report['suggestions'][:5]:
            print(f"   - {suggestion['current_name']} → {suggestion['suggested_fix']} ({suggestion['violation_type']})")

if __name__ == "__main__":
    main()