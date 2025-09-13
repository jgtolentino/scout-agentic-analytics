#!/usr/bin/env python3
"""
Feature Extractor - Repository Capability Detection
Scans migrations and Edge Functions to build comprehensive feature taxonomy
"""

import os
import re
import yaml
import json
import glob
from pathlib import Path
from typing import Dict, List, Set
from dataclasses import dataclass, asdict

@dataclass
class FeatureCapability:
    name: str
    domain: str
    files: List[str]
    patterns: List[str]
    confidence: float

@dataclass
class RepositoryIntel:
    capabilities: List[FeatureCapability]
    namespaces: Dict[str, List[str]]
    violations: List[str]
    metrics: Dict[str, int]

class FeatureExtractor:
    def __init__(self, repo_root: str):
        self.repo_root = Path(repo_root)
        self.taxonomy = self._load_taxonomy()
        self.schema_registry = self._load_schema_registry()
        
    def _load_taxonomy(self) -> Dict:
        """Load feature taxonomy configuration"""
        try:
            with open(self.repo_root / 'FEATURE_TAXONOMY.yaml', 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            return {}
    
    def _load_schema_registry(self) -> Dict:
        """Load schema registry configuration"""
        try:
            with open(self.repo_root / 'SCHEMA_REGISTRY.yaml', 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            return {}
    
    def extract_from_migrations(self) -> List[FeatureCapability]:
        """Extract capabilities from Supabase migrations"""
        capabilities = []
        migrations_path = self.repo_root / 'supabase' / 'migrations'
        
        if not migrations_path.exists():
            return capabilities
            
        for migration_file in migrations_path.glob('*.sql'):
            try:
                content = migration_file.read_text(encoding='utf-8')
            except UnicodeDecodeError:
                try:
                    content = migration_file.read_text(encoding='latin-1')
                except UnicodeDecodeError:
                    print(f"⚠️ Skipping {migration_file} due to encoding issues")
                    continue
            
            # Detect table creation patterns
            table_matches = re.findall(r'CREATE TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:[a-zA-Z_]+\.)?([a-zA-Z_]+)', content, re.IGNORECASE)
            for table in table_matches:
                domain = self._classify_table_domain(table)
                if domain:
                    capabilities.append(FeatureCapability(
                        name=f"table_{table}",
                        domain=domain,
                        files=[str(migration_file)],
                        patterns=[f"CREATE TABLE {table}"],
                        confidence=0.9
                    ))
            
            # Detect function creation patterns
            function_matches = re.findall(r'CREATE.*FUNCTION\s+(?:[a-zA-Z_]+\.)?([a-zA-Z_]+)', content, re.IGNORECASE)
            for function in function_matches:
                domain = self._classify_function_domain(function)
                if domain:
                    capabilities.append(FeatureCapability(
                        name=f"function_{function}",
                        domain=domain,
                        files=[str(migration_file)],
                        patterns=[f"CREATE FUNCTION {function}"],
                        confidence=0.8
                    ))
        
        return capabilities
    
    def extract_from_edge_functions(self) -> List[FeatureCapability]:
        """Extract capabilities from Supabase Edge Functions"""
        capabilities = []
        functions_path = self.repo_root / 'supabase' / 'functions'
        
        if not functions_path.exists():
            return capabilities
            
        for function_dir in functions_path.iterdir():
            if function_dir.is_dir():
                index_file = function_dir / 'index.ts'
                if index_file.exists():
                    try:
                        content = index_file.read_text(encoding='utf-8')
                    except UnicodeDecodeError:
                        try:
                            content = index_file.read_text(encoding='latin-1')
                        except UnicodeDecodeError:
                            print(f"⚠️ Skipping {index_file} due to encoding issues")
                            continue
                    domain = self._classify_function_domain(function_dir.name)
                    
                    # Analyze function capabilities
                    patterns = self._extract_code_patterns(content)
                    
                    capabilities.append(FeatureCapability(
                        name=f"edge_function_{function_dir.name}",
                        domain=domain or "api_services",
                        files=[str(index_file)],
                        patterns=patterns,
                        confidence=0.85
                    ))
        
        return capabilities
    
    def _classify_table_domain(self, table_name: str) -> str:
        """Classify table into domain based on naming patterns"""
        if table_name.startswith('scout_'):
            return 'analytics'
        elif table_name.startswith('ces_'):
            return 'analytics'
        elif table_name.startswith('neural_'):
            return 'machine_learning'
        elif 'auth' in table_name or 'user' in table_name:
            return 'api_services'
        return 'data_pipeline'
    
    def _classify_function_domain(self, function_name: str) -> str:
        """Classify function into domain based on naming patterns"""
        if 'scout' in function_name:
            return 'analytics'
        elif 'ces' in function_name:
            return 'analytics'
        elif 'neural' in function_name or 'predict' in function_name:
            return 'machine_learning'
        elif 'etl' in function_name or 'pipeline' in function_name:
            return 'data_pipeline'
        return 'api_services'
    
    def _extract_code_patterns(self, content: str) -> List[str]:
        """Extract code patterns from function content"""
        patterns = []
        
        # API patterns
        if re.search(r'(GET|POST|PUT|DELETE)', content):
            patterns.append('rest_api')
        
        # Database patterns
        if re.search(r'(SELECT|INSERT|UPDATE|DELETE)', content, re.IGNORECASE):
            patterns.append('database_operations')
        
        # ML patterns
        if re.search(r'(predict|model|neural|ml)', content, re.IGNORECASE):
            patterns.append('machine_learning')
        
        # Authentication patterns
        if re.search(r'(auth|jwt|token|session)', content, re.IGNORECASE):
            patterns.append('authentication')
        
        return patterns
    
    def validate_namespaces(self) -> List[str]:
        """Validate namespace compliance against schema registry"""
        violations = []
        
        if not self.schema_registry:
            return violations
        
        # Check table naming compliance
        migrations_path = self.repo_root / 'supabase' / 'migrations'
        if migrations_path.exists():
            for migration_file in migrations_path.glob('*.sql'):
                try:
                    content = migration_file.read_text(encoding='utf-8')
                except UnicodeDecodeError:
                    try:
                        content = migration_file.read_text(encoding='latin-1')
                    except UnicodeDecodeError:
                        print(f"⚠️ Skipping {migration_file} due to encoding issues")
                        continue
                tables = re.findall(r'CREATE TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:[a-zA-Z_]+\.)?([a-zA-Z_]+)', content, re.IGNORECASE)
                
                for table in tables:
                    if not self._validate_table_naming(table):
                        violations.append(f"Table naming violation: {table} in {migration_file.name}")
        
        return violations
    
    def _validate_table_naming(self, table_name: str) -> bool:
        """Validate table naming against schema registry rules"""
        rules = self.schema_registry.get('validation_rules', {})
        table_pattern = rules.get('table_naming', '')
        
        if table_pattern:
            return bool(re.match(table_pattern, table_name))
        return True
    
    def generate_intel_report(self) -> RepositoryIntel:
        """Generate comprehensive repository intelligence report"""
        migration_capabilities = self.extract_from_migrations()
        edge_function_capabilities = self.extract_from_edge_functions()
        
        all_capabilities = migration_capabilities + edge_function_capabilities
        
        # Group capabilities by namespace
        namespaces = {}
        for cap in all_capabilities:
            domain = cap.domain
            if domain not in namespaces:
                namespaces[domain] = []
            namespaces[domain].append(cap.name)
        
        # Validate namespace compliance
        violations = self.validate_namespaces()
        
        # Calculate metrics
        metrics = {
            'total_capabilities': len(all_capabilities),
            'migration_capabilities': len(migration_capabilities),
            'edge_function_capabilities': len(edge_function_capabilities),
            'namespace_violations': len(violations),
            'domains_detected': len(namespaces)
        }
        
        return RepositoryIntel(
            capabilities=all_capabilities,
            namespaces=namespaces,
            violations=violations,
            metrics=metrics
        )
    
    def export_report(self, output_file: str = 'repo_intel_report.json'):
        """Export intelligence report to JSON"""
        intel = self.generate_intel_report()
        
        # Convert to serializable format
        report_data = {
            'capabilities': [asdict(cap) for cap in intel.capabilities],
            'namespaces': intel.namespaces,
            'violations': intel.violations,
            'metrics': intel.metrics,
            'timestamp': '2025-09-12T11:30:00Z'
        }
        
        output_path = self.repo_root / output_file
        with open(output_path, 'w') as f:
            json.dump(report_data, f, indent=2)
        
        print(f"📊 Repository intelligence report exported to: {output_path}")
        return report_data

def main():
    """Main execution function"""
    repo_root = os.getcwd()
    extractor = FeatureExtractor(repo_root)
    
    print("🔍 Extracting repository capabilities...")
    report = extractor.export_report()
    
    print(f"✅ Analysis complete:")
    print(f"   - Total capabilities: {report['metrics']['total_capabilities']}")
    print(f"   - Domains detected: {report['metrics']['domains_detected']}")
    print(f"   - Namespace violations: {report['metrics']['namespace_violations']}")
    
    if report['violations']:
        print("⚠️  Namespace violations detected:")
        for violation in report['violations'][:5]:  # Show first 5
            print(f"   - {violation}")

if __name__ == "__main__":
    main()