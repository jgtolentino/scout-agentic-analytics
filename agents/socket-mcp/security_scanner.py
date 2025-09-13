#!/usr/bin/env python3
"""
Security scanner for local artifacts
Integrates with OSV, Snyk, and other vulnerability databases
"""

import os
import json
import hashlib
import aiohttp
import asyncio
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
import logging
import re

logger = logging.getLogger('socket-mcp.security')

@dataclass
class Vulnerability:
    id: str
    severity: str  # critical, high, medium, low
    summary: str
    details: Optional[str] = None
    affected_versions: List[str] = None
    fixed_versions: List[str] = None
    cve: Optional[str] = None
    references: List[str] = None
    published_date: Optional[datetime] = None

@dataclass
class SecurityScanResult:
    artifact_path: str
    scan_date: datetime
    vulnerabilities: List[Vulnerability]
    risk_score: float  # 0-10
    recommendations: List[str]
    scan_engines_used: List[str]

class VulnerabilityDatabase:
    """Base class for vulnerability database integrations"""
    
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key
        self.session = None
        
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
        
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
            
    async def check_vulnerability(self, package_name: str, version: str) -> List[Vulnerability]:
        """Check for vulnerabilities in a package"""
        raise NotImplementedError

class OSVDatabase(VulnerabilityDatabase):
    """OSV (Open Source Vulnerabilities) database integration"""
    
    BASE_URL = "https://api.osv.dev/v1"
    
    async def check_vulnerability(self, package_name: str, version: str, 
                                ecosystem: str = "npm") -> List[Vulnerability]:
        """Query OSV database for vulnerabilities"""
        vulnerabilities = []
        
        # Query by package
        query = {
            "package": {
                "name": package_name,
                "ecosystem": ecosystem.upper()
            },
            "version": version
        }
        
        try:
            async with self.session.post(f"{self.BASE_URL}/query", json=query) as response:
                if response.status == 200:
                    data = await response.json()
                    
                    for vuln_data in data.get('vulns', []):
                        vuln = self._parse_osv_vulnerability(vuln_data)
                        if vuln:
                            vulnerabilities.append(vuln)
                            
        except Exception as e:
            logger.error(f"OSV query failed for {package_name}@{version}: {e}")
            
        return vulnerabilities
        
    def _parse_osv_vulnerability(self, data: Dict) -> Optional[Vulnerability]:
        """Parse OSV vulnerability format"""
        try:
            # Extract severity
            severity = 'medium'  # Default
            if 'database_specific' in data and 'severity' in data['database_specific']:
                severity = data['database_specific']['severity'].lower()
            elif 'severity' in data:
                severity = data['severity'][0]['type'].lower() if data['severity'] else 'medium'
                
            # Extract affected versions
            affected_versions = []
            fixed_versions = []
            
            for affected in data.get('affected', []):
                for range_data in affected.get('ranges', []):
                    if 'introduced' in range_data.get('events', [{}])[0]:
                        affected_versions.append(range_data['events'][0]['introduced'])
                    if 'fixed' in range_data.get('events', [{}])[-1]:
                        fixed_versions.append(range_data['events'][-1]['fixed'])
                        
            return Vulnerability(
                id=data.get('id', 'unknown'),
                severity=severity,
                summary=data.get('summary', ''),
                details=data.get('details'),
                affected_versions=affected_versions,
                fixed_versions=fixed_versions,
                cve=self._extract_cve(data),
                references=[ref.get('url') for ref in data.get('references', [])],
                published_date=datetime.fromisoformat(data['published'].replace('Z', '+00:00')) 
                    if 'published' in data else None
            )
        except Exception as e:
            logger.error(f"Failed to parse OSV vulnerability: {e}")
            return None
            
    def _extract_cve(self, data: Dict) -> Optional[str]:
        """Extract CVE ID from vulnerability data"""
        for alias in data.get('aliases', []):
            if alias.startswith('CVE-'):
                return alias
        return None

class SnykDatabase(VulnerabilityDatabase):
    """Snyk vulnerability database integration"""
    
    BASE_URL = "https://api.snyk.io/v1"
    
    async def check_vulnerability(self, package_name: str, version: str,
                                ecosystem: str = "npm") -> List[Vulnerability]:
        """Query Snyk API for vulnerabilities"""
        if not self.api_key:
            logger.warning("Snyk API key not configured")
            return []
            
        vulnerabilities = []
        headers = {'Authorization': f'token {self.api_key}'}
        
        # Map ecosystem to Snyk package manager
        pm_map = {
            'npm': 'npm',
            'pypi': 'pip',
            'maven': 'maven',
            'rubygems': 'rubygems'
        }
        
        package_manager = pm_map.get(ecosystem.lower(), 'npm')
        
        try:
            url = f"{self.BASE_URL}/test/{package_manager}/{package_name}/{version}"
            async with self.session.get(url, headers=headers) as response:
                if response.status == 200:
                    data = await response.json()
                    
                    for issue in data.get('issues', {}).get('vulnerabilities', []):
                        vuln = self._parse_snyk_vulnerability(issue)
                        if vuln:
                            vulnerabilities.append(vuln)
                            
        except Exception as e:
            logger.error(f"Snyk query failed for {package_name}@{version}: {e}")
            
        return vulnerabilities
        
    def _parse_snyk_vulnerability(self, data: Dict) -> Optional[Vulnerability]:
        """Parse Snyk vulnerability format"""
        try:
            return Vulnerability(
                id=data.get('id', 'unknown'),
                severity=data.get('severity', 'medium').lower(),
                summary=data.get('title', ''),
                details=data.get('description'),
                affected_versions=[data.get('version')] if 'version' in data else [],
                fixed_versions=data.get('fixedIn', []),
                cve=data.get('identifiers', {}).get('CVE', [None])[0],
                references=[data.get('url')] if 'url' in data else []
            )
        except Exception as e:
            logger.error(f"Failed to parse Snyk vulnerability: {e}")
            return None

class LocalArtifactSecurityScanner:
    """Security scanner for local artifacts"""
    
    def __init__(self, config: Dict):
        self.config = config
        self.severity_scores = {
            'critical': 10,
            'high': 7,
            'medium': 4,
            'low': 1
        }
        
    async def scan_artifact(self, artifact_path: str, manifest: Dict = None) -> SecurityScanResult:
        """Scan local artifact for security vulnerabilities"""
        scan_engines = []
        all_vulnerabilities = []
        
        # Determine package info from manifest
        if manifest:
            package_name = manifest.get('name', '')
            version = manifest.get('version', '')
            ecosystem = self._detect_ecosystem(artifact_path, manifest)
            
            # Use OSV database (free, no API key required)
            async with OSVDatabase() as osv:
                osv_vulns = await osv.check_vulnerability(package_name, version, ecosystem)
                all_vulnerabilities.extend(osv_vulns)
                scan_engines.append('OSV')
                
            # Use Snyk if API key available
            snyk_api_key = os.environ.get('SNYK_API_KEY')
            if snyk_api_key:
                async with SnykDatabase(snyk_api_key) as snyk:
                    snyk_vulns = await snyk.check_vulnerability(package_name, version, ecosystem)
                    all_vulnerabilities.extend(snyk_vulns)
                    scan_engines.append('Snyk')
                    
        # Scan for known vulnerable patterns in files
        file_vulns = await self._scan_files_for_patterns(artifact_path)
        all_vulnerabilities.extend(file_vulns)
        if file_vulns:
            scan_engines.append('Pattern Scanner')
            
        # Calculate risk score
        risk_score = self._calculate_risk_score(all_vulnerabilities)
        
        # Generate recommendations
        recommendations = self._generate_recommendations(all_vulnerabilities, manifest)
        
        return SecurityScanResult(
            artifact_path=artifact_path,
            scan_date=datetime.now(),
            vulnerabilities=all_vulnerabilities,
            risk_score=risk_score,
            recommendations=recommendations,
            scan_engines_used=scan_engines
        )
        
    def _detect_ecosystem(self, artifact_path: str, manifest: Dict) -> str:
        """Detect package ecosystem from artifact"""
        path = Path(artifact_path)
        
        # Check file extension
        if path.suffix in ['.jar', '.war', '.ear']:
            return 'maven'
        elif path.suffix in ['.whl', '.egg']:
            return 'pypi'
        elif path.name == 'package.json' or 'node_modules' in str(path):
            return 'npm'
        elif path.suffix == '.gem':
            return 'rubygems'
            
        # Check manifest hints
        if manifest:
            if 'dependencies' in manifest and 'devDependencies' in manifest:
                return 'npm'
            elif 'install_requires' in manifest:
                return 'pypi'
                
        return 'unknown'
        
    async def _scan_files_for_patterns(self, artifact_path: str) -> List[Vulnerability]:
        """Scan files for vulnerable patterns"""
        vulnerabilities = []
        path = Path(artifact_path)
        
        # Common vulnerable patterns
        patterns = [
            {
                'pattern': r'eval\s*\([^)]*\$|exec\s*\([^)]*\$',
                'severity': 'high',
                'summary': 'Potential code injection vulnerability',
                'details': 'Found eval() or exec() with variable input'
            },
            {
                'pattern': r'password\s*=\s*["\'][^"\']+["\']',
                'severity': 'critical',
                'summary': 'Hardcoded password detected',
                'details': 'Found hardcoded password in source code'
            },
            {
                'pattern': r'api[_-]?key\s*=\s*["\'][^"\']+["\']',
                'severity': 'high',
                'summary': 'Hardcoded API key detected',
                'details': 'Found hardcoded API key in source code'
            },
            {
                'pattern': r'md5\s*\(|MD5\s*\.',
                'severity': 'medium',
                'summary': 'Weak cryptographic algorithm (MD5)',
                'details': 'MD5 is cryptographically broken and should not be used'
            }
        ]
        
        # Scan files
        files_to_scan = []
        if path.is_file():
            files_to_scan = [path]
        else:
            # Scan source files in directory
            for ext in ['.js', '.py', '.java', '.rb', '.php']:
                files_to_scan.extend(path.rglob(f'*{ext}'))
                
        for file_path in files_to_scan[:100]:  # Limit to 100 files
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    
                for pattern_config in patterns:
                    if re.search(pattern_config['pattern'], content):
                        vulnerabilities.append(Vulnerability(
                            id=f"pattern-{hashlib.md5(pattern_config['pattern'].encode()).hexdigest()[:8]}",
                            severity=pattern_config['severity'],
                            summary=pattern_config['summary'],
                            details=f"{pattern_config['details']} in {file_path.name}"
                        ))
                        
            except Exception as e:
                logger.debug(f"Could not scan {file_path}: {e}")
                
        return vulnerabilities
        
    def _calculate_risk_score(self, vulnerabilities: List[Vulnerability]) -> float:
        """Calculate overall risk score (0-10)"""
        if not vulnerabilities:
            return 0.0
            
        total_score = 0
        for vuln in vulnerabilities:
            total_score += self.severity_scores.get(vuln.severity, 1)
            
        # Normalize to 0-10 scale
        # Max possible score per vuln is 10, so normalize by count
        risk_score = min(total_score / len(vulnerabilities) * 2, 10.0)
        
        return round(risk_score, 1)
        
    def _generate_recommendations(self, vulnerabilities: List[Vulnerability], 
                                manifest: Dict = None) -> List[str]:
        """Generate security recommendations"""
        recommendations = []
        
        if not vulnerabilities:
            recommendations.append("No vulnerabilities detected. Keep dependencies updated.")
            return recommendations
            
        # Group by severity
        severity_counts = {}
        for vuln in vulnerabilities:
            severity_counts[vuln.severity] = severity_counts.get(vuln.severity, 0) + 1
            
        # Critical vulnerabilities
        if severity_counts.get('critical', 0) > 0:
            recommendations.append(
                f"⚠️ URGENT: {severity_counts['critical']} critical vulnerabilities found. "
                "Update affected packages immediately."
            )
            
        # Check for available fixes
        fixable = [v for v in vulnerabilities if v.fixed_versions]
        if fixable:
            recommendations.append(
                f"✅ {len(fixable)} vulnerabilities have fixes available. "
                "Run update commands to apply fixes."
            )
            
            # Suggest specific updates
            if manifest and 'name' in manifest:
                latest_fix = max(fixable[0].fixed_versions) if fixable[0].fixed_versions else None
                if latest_fix:
                    recommendations.append(
                        f"Update {manifest['name']} to version {latest_fix} or higher"
                    )
                    
        # Pattern-based vulnerabilities
        pattern_vulns = [v for v in vulnerabilities if v.id.startswith('pattern-')]
        if pattern_vulns:
            recommendations.append(
                f"🔍 {len(pattern_vulns)} potential security issues found in source code. "
                "Review and remediate identified patterns."
            )
            
        # General recommendations
        if len(vulnerabilities) > 5:
            recommendations.append(
                "Consider using automated dependency updates (Dependabot, Renovate) "
                "to stay current with security patches."
            )
            
        return recommendations

class SecurityAuditor:
    """Comprehensive security audit orchestrator"""
    
    def __init__(self, config: Dict):
        self.config = config
        self.scanner = LocalArtifactSecurityScanner(config)
        
    async def audit_project(self, project_path: str) -> Dict:
        """Perform comprehensive security audit of project"""
        audit_result = {
            'project_path': project_path,
            'audit_date': datetime.now().isoformat(),
            'total_artifacts': 0,
            'vulnerable_artifacts': 0,
            'critical_issues': 0,
            'risk_score': 0.0,
            'artifacts': [],
            'summary': {},
            'action_items': []
        }
        
        # Find all artifacts to scan
        artifacts = self._find_artifacts(project_path)
        audit_result['total_artifacts'] = len(artifacts)
        
        # Scan each artifact
        all_vulnerabilities = []
        
        for artifact_path, manifest in artifacts:
            scan_result = await self.scanner.scan_artifact(artifact_path, manifest)
            
            audit_result['artifacts'].append({
                'path': artifact_path,
                'risk_score': scan_result.risk_score,
                'vulnerability_count': len(scan_result.vulnerabilities),
                'scan_result': asdict(scan_result)
            })
            
            if scan_result.vulnerabilities:
                audit_result['vulnerable_artifacts'] += 1
                all_vulnerabilities.extend(scan_result.vulnerabilities)
                
                # Count critical issues
                critical = [v for v in scan_result.vulnerabilities if v.severity == 'critical']
                audit_result['critical_issues'] += len(critical)
                
        # Calculate overall risk score
        if audit_result['artifacts']:
            total_risk = sum(a['risk_score'] for a in audit_result['artifacts'])
            audit_result['risk_score'] = round(total_risk / len(audit_result['artifacts']), 1)
            
        # Generate summary
        audit_result['summary'] = self._generate_audit_summary(all_vulnerabilities)
        
        # Generate action items
        audit_result['action_items'] = self._generate_action_items(
            all_vulnerabilities, 
            audit_result['vulnerable_artifacts']
        )
        
        return audit_result
        
    def _find_artifacts(self, project_path: str) -> List[Tuple[str, Optional[Dict]]]:
        """Find all artifacts in project"""
        artifacts = []
        path = Path(project_path)
        
        # Look for package files
        package_files = [
            ('package.json', self._read_json),
            ('requirements.txt', None),
            ('pom.xml', None),
            ('build.gradle', None),
            ('Gemfile', None)
        ]
        
        for filename, parser in package_files:
            for file_path in path.rglob(filename):
                manifest = None
                if parser:
                    try:
                        manifest = parser(file_path)
                    except:
                        pass
                artifacts.append((str(file_path), manifest))
                
        # Look for built artifacts
        artifact_patterns = ['*.jar', '*.whl', '*.gem', '*.egg']
        for pattern in artifact_patterns:
            for file_path in path.rglob(pattern):
                artifacts.append((str(file_path), None))
                
        return artifacts
        
    def _read_json(self, file_path: Path) -> Optional[Dict]:
        """Read JSON file"""
        try:
            with open(file_path, 'r') as f:
                return json.load(f)
        except:
            return None
            
    def _generate_audit_summary(self, vulnerabilities: List[Vulnerability]) -> Dict:
        """Generate audit summary statistics"""
        summary = {
            'total_vulnerabilities': len(vulnerabilities),
            'by_severity': {},
            'top_cves': [],
            'affected_packages': set()
        }
        
        # Count by severity
        for vuln in vulnerabilities:
            severity = vuln.severity
            summary['by_severity'][severity] = summary['by_severity'].get(severity, 0) + 1
            
            # Track CVEs
            if vuln.cve:
                summary['top_cves'].append(vuln.cve)
                
        summary['top_cves'] = summary['top_cves'][:10]  # Top 10 CVEs
        
        return summary
        
    def _generate_action_items(self, vulnerabilities: List[Vulnerability], 
                             vulnerable_count: int) -> List[Dict]:
        """Generate prioritized action items"""
        action_items = []
        
        # Critical vulnerabilities first
        critical_vulns = [v for v in vulnerabilities if v.severity == 'critical']
        if critical_vulns:
            action_items.append({
                'priority': 'CRITICAL',
                'action': f'Address {len(critical_vulns)} critical vulnerabilities immediately',
                'details': 'These pose immediate risk to your application security'
            })
            
        # High vulnerabilities
        high_vulns = [v for v in vulnerabilities if v.severity == 'high']
        if high_vulns:
            action_items.append({
                'priority': 'HIGH',
                'action': f'Fix {len(high_vulns)} high severity vulnerabilities',
                'details': 'Schedule updates within the next sprint'
            })
            
        # Update recommendations
        if vulnerable_count > 0:
            action_items.append({
                'priority': 'MEDIUM',
                'action': 'Update all vulnerable dependencies',
                'details': f'{vulnerable_count} artifacts have known vulnerabilities'
            })
            
        # Preventive measures
        action_items.append({
            'priority': 'LOW',
            'action': 'Implement automated security scanning',
            'details': 'Add security scanning to CI/CD pipeline'
        })
        
        return action_items

# Export main classes
__all__ = ['LocalArtifactSecurityScanner', 'SecurityAuditor', 'Vulnerability', 'SecurityScanResult']