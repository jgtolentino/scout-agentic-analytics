#!/usr/bin/env python3

"""
Scout Analytics - Dependency Resolution Script
Resolves and merges dependencies from multiple package.json files
"""

import json
import os
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Tuple
import semver
import argparse

class DependencyResolver:
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.dependencies = defaultdict(dict)
        self.dev_dependencies = defaultdict(dict)
        self.peer_dependencies = defaultdict(dict)
        self.conflicts = []
        self.resolutions = {}
        
    def find_package_files(self) -> List[Path]:
        """Find all package.json files in the project"""
        package_files = []
        for root, dirs, files in os.walk(self.project_root):
            # Skip node_modules directories
            if 'node_modules' in dirs:
                dirs.remove('node_modules')
            
            if 'package.json' in files:
                package_files.append(Path(root) / 'package.json')
                
        return package_files
    
    def parse_version_range(self, version: str) -> Tuple[str, str]:
        """Parse version range and return min/max versions"""
        # Handle different version specifiers
        if version.startswith('^'):
            base = version[1:]
            parsed = semver.VersionInfo.parse(base)
            max_version = f"{parsed.major + 1}.0.0"
            return base, max_version
        elif version.startswith('~'):
            base = version[1:]
            parsed = semver.VersionInfo.parse(base)
            max_version = f"{parsed.major}.{parsed.minor + 1}.0"
            return base, max_version
        elif version.startswith('>='):
            return version[2:], None
        elif version.startswith('>'):
            return version[1:], None
        else:
            # Exact version
            return version, version
    
    def resolve_version_conflict(self, package: str, versions: Dict[str, List[str]]) -> str:
        """Resolve version conflicts between multiple sources"""
        all_versions = []
        
        for version, sources in versions.items():
            try:
                # Extract base version for comparison
                if version.startswith('^') or version.startswith('~'):
                    base_version = version[1:]
                else:
                    base_version = version
                    
                all_versions.append((version, base_version, sources))
            except:
                print(f"Warning: Could not parse version {version} for {package}")
                
        if not all_versions:
            return "*"
        
        # Sort by semantic version (highest first)
        try:
            all_versions.sort(key=lambda x: semver.VersionInfo.parse(x[1]), reverse=True)
        except:
            # If semantic versioning fails, use string comparison
            all_versions.sort(key=lambda x: x[1], reverse=True)
        
        # Use the highest version
        resolved_version = all_versions[0][0]
        
        # Log conflict if multiple different versions exist
        if len(set(v[0] for v in all_versions)) > 1:
            self.conflicts.append({
                'package': package,
                'versions': {v[0]: v[2] for v in all_versions},
                'resolved': resolved_version
            })
            
        return resolved_version
    
    def collect_dependencies(self):
        """Collect all dependencies from package.json files"""
        package_files = self.find_package_files()
        
        for package_file in package_files:
            relative_path = package_file.relative_to(self.project_root)
            
            try:
                with open(package_file, 'r') as f:
                    data = json.load(f)
                    
                # Collect regular dependencies
                if 'dependencies' in data:
                    for pkg, version in data['dependencies'].items():
                        if pkg not in self.dependencies:
                            self.dependencies[pkg] = {}
                        if version not in self.dependencies[pkg]:
                            self.dependencies[pkg][version] = []
                        self.dependencies[pkg][version].append(str(relative_path))
                
                # Collect dev dependencies
                if 'devDependencies' in data:
                    for pkg, version in data['devDependencies'].items():
                        if pkg not in self.dev_dependencies:
                            self.dev_dependencies[pkg] = {}
                        if version not in self.dev_dependencies[pkg]:
                            self.dev_dependencies[pkg][version] = []
                        self.dev_dependencies[pkg][version].append(str(relative_path))
                        
                # Collect peer dependencies
                if 'peerDependencies' in data:
                    for pkg, version in data['peerDependencies'].items():
                        if pkg not in self.peer_dependencies:
                            self.peer_dependencies[pkg] = {}
                        if version not in self.peer_dependencies[pkg]:
                            self.peer_dependencies[pkg][version] = []
                        self.peer_dependencies[pkg][version].append(str(relative_path))
                        
            except Exception as e:
                print(f"Error reading {package_file}: {e}")
    
    def resolve_all_dependencies(self):
        """Resolve all dependency conflicts"""
        resolved = {
            'dependencies': {},
            'devDependencies': {},
            'peerDependencies': {}
        }
        
        # Resolve regular dependencies
        for package, versions in self.dependencies.items():
            resolved['dependencies'][package] = self.resolve_version_conflict(package, versions)
            
        # Resolve dev dependencies
        for package, versions in self.dev_dependencies.items():
            # Don't include in devDependencies if already in dependencies
            if package not in resolved['dependencies']:
                resolved['devDependencies'][package] = self.resolve_version_conflict(package, versions)
                
        # Resolve peer dependencies
        for package, versions in self.peer_dependencies.items():
            resolved['peerDependencies'][package] = self.resolve_version_conflict(package, versions)
            
        return resolved
    
    def generate_report(self) -> str:
        """Generate a conflict resolution report"""
        report = ["# Dependency Resolution Report\n"]
        
        if self.conflicts:
            report.append("## Conflicts Resolved\n")
            for conflict in self.conflicts:
                report.append(f"### {conflict['package']}")
                report.append("Versions found:")
                for version, sources in conflict['versions'].items():
                    report.append(f"  - `{version}` from:")
                    for source in sources:
                        report.append(f"    - {source}")
                report.append(f"**Resolved to:** `{conflict['resolved']}`\n")
        else:
            report.append("No conflicts found! ✅\n")
            
        # Statistics
        report.append("## Statistics\n")
        report.append(f"- Total dependencies: {len(self.dependencies)}")
        report.append(f"- Total devDependencies: {len(self.dev_dependencies)}")
        report.append(f"- Total peerDependencies: {len(self.peer_dependencies)}")
        report.append(f"- Conflicts resolved: {len(self.conflicts)}")
        
        return "\n".join(report)
    
    def create_merged_package_json(self, output_path: str):
        """Create a merged package.json file"""
        resolved = self.resolve_all_dependencies()
        
        merged_package = {
            "name": "scout-analytics-dashboard",
            "version": "1.0.0",
            "description": "Comprehensive retail analytics platform",
            "private": True,
            "workspaces": ["frontend", "backend"],
            "scripts": {
                "dev": "concurrently \"npm run dev:frontend\" \"npm run dev:backend\"",
                "dev:frontend": "cd frontend && npm run dev",
                "dev:backend": "cd backend && npm run dev",
                "build": "npm run build:frontend && npm run build:backend",
                "build:frontend": "cd frontend && npm run build",
                "build:backend": "cd backend && npm run build",
                "test": "npm run test:frontend && npm run test:backend",
                "test:frontend": "cd frontend && npm test",
                "test:backend": "cd backend && npm test",
                "lint": "npm run lint:frontend && npm run lint:backend",
                "lint:frontend": "cd frontend && npm run lint",
                "lint:backend": "cd backend && npm run lint"
            },
            "dependencies": resolved['dependencies'],
            "devDependencies": {
                **resolved['devDependencies'],
                "concurrently": "^8.2.2"
            }
        }
        
        # Add peer dependencies if any
        if resolved['peerDependencies']:
            merged_package['peerDependencies'] = resolved['peerDependencies']
            
        # Add resolutions for Yarn/pnpm
        if self.conflicts:
            merged_package['resolutions'] = {}
            merged_package['overrides'] = {}  # npm 8.3+
            
            for conflict in self.conflicts:
                merged_package['resolutions'][conflict['package']] = conflict['resolved']
                merged_package['overrides'][conflict['package']] = conflict['resolved']
        
        # Write the merged package.json
        with open(output_path, 'w') as f:
            json.dump(merged_package, f, indent=2)
            
        print(f"✅ Merged package.json written to: {output_path}")
        
        # Write the report
        report_path = Path(output_path).parent / "DEPENDENCY_RESOLUTION_REPORT.md"
        with open(report_path, 'w') as f:
            f.write(self.generate_report())
            
        print(f"📄 Resolution report written to: {report_path}")


def main():
    parser = argparse.ArgumentParser(description='Resolve dependencies for Scout Analytics')
    parser.add_argument('project_root', help='Root directory of the project')
    parser.add_argument('-o', '--output', default='package.json', help='Output package.json path')
    parser.add_argument('--check-only', action='store_true', help='Only check for conflicts')
    
    args = parser.parse_args()
    
    resolver = DependencyResolver(args.project_root)
    
    print("🔍 Scanning for package.json files...")
    resolver.collect_dependencies()
    
    if args.check_only:
        resolver.resolve_all_dependencies()
        print(resolver.generate_report())
    else:
        resolver.create_merged_package_json(args.output)
        
        if resolver.conflicts:
            print(f"\n⚠️  Found and resolved {len(resolver.conflicts)} conflicts")
            print("See DEPENDENCY_RESOLUTION_REPORT.md for details")


if __name__ == "__main__":
    main()