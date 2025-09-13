#!/usr/bin/env python3
"""
Socket MCP - Enhanced Build Guardrail & Dependency Validation Agent
Robust error-tolerant dependency validation with local artifact scanning
"""

import os
import sys
import json
import time
import hashlib
import zipfile
import tarfile
import asyncio
import argparse
import logging
from pathlib import Path
from typing import Dict, List, Optional, Union, Tuple, Any
from dataclasses import dataclass, asdict
from datetime import datetime
from urllib.parse import urlparse
import subprocess
import re
from enum import Enum
import tempfile
import shutil

# Third-party imports
try:
    import aiohttp
    import yaml
    from aiofiles import open as aio_open
    import magic  # python-magic for file type detection
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Install with: pip install aiohttp pyyaml aiofiles python-magic")
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('socket-mcp')

class ErrorCategory(Enum):
    NETWORK = "network_error"
    PACKAGE_NOT_FOUND = "package_not_found"
    VERSION_MISMATCH = "version_mismatch"
    BUILD_FAILURE = "build_failure"
    CHECKSUM_MISMATCH = "checksum_mismatch"
    MISSING_DEPENDENCY = "missing_dependency"
    SECURITY_VULNERABILITY = "security_vulnerability"
    INVALID_ARTIFACT = "invalid_artifact"

class ArtifactType(Enum):
    JAR = "jar"
    WHEEL = "wheel"
    NPM = "npm"
    TARBALL = "tarball"
    UNKNOWN = "unknown"

@dataclass
class ValidationResult:
    artifact_path: str
    artifact_type: ArtifactType
    is_valid: bool
    checksum: Optional[str] = None
    manifest: Optional[Dict] = None
    errors: List[str] = None
    warnings: List[str] = None
    metadata: Optional[Dict] = None

@dataclass
class DependencyScore:
    package: str
    version: str
    score: float
    risk_level: str
    vulnerabilities: List[Dict]
    license: Optional[str] = None
    source: str = "registry"  # registry or local

@dataclass
class ErrorReport:
    category: ErrorCategory
    message: str
    timestamp: datetime
    retry_count: int
    resolved: bool
    suggested_fix: Optional[str] = None
    context: Optional[Dict] = None

class RetryHandler:
    """Exponential backoff retry handler with circuit breaker"""
    
    def __init__(self, max_retries: int = 3, initial_delay: float = 1.0, 
                 backoff_factor: float = 2.0, circuit_breaker_threshold: int = 5):
        self.max_retries = max_retries
        self.initial_delay = initial_delay
        self.backoff_factor = backoff_factor
        self.circuit_breaker_threshold = circuit_breaker_threshold
        self.failure_count = 0
        self.circuit_open = False
        self.circuit_open_time = None
        
    async def execute_with_retry(self, func, *args, **kwargs):
        """Execute function with exponential backoff retry"""
        if self.circuit_open:
            if time.time() - self.circuit_open_time > 60:  # 1 minute recovery
                self.circuit_open = False
                self.failure_count = 0
            else:
                raise Exception("Circuit breaker is open")
                
        last_exception = None
        
        for attempt in range(self.max_retries + 1):
            try:
                result = await func(*args, **kwargs)
                self.failure_count = 0  # Reset on success
                return result
            except Exception as e:
                last_exception = e
                self.failure_count += 1
                
                if self.failure_count >= self.circuit_breaker_threshold:
                    self.circuit_open = True
                    self.circuit_open_time = time.time()
                    logger.error(f"Circuit breaker opened after {self.failure_count} failures")
                    
                if attempt < self.max_retries:
                    delay = self.initial_delay * (self.backoff_factor ** attempt)
                    logger.warning(f"Retry {attempt + 1}/{self.max_retries} after {delay}s: {str(e)}")
                    await asyncio.sleep(delay)
                    
        raise last_exception

class LocalArtifactScanner:
    """Scan and validate local artifacts (JARs, wheels, node_modules)"""
    
    def __init__(self, config: Dict):
        self.config = config
        self.file_magic = magic.Magic(mime=True)
        
    async def scan_artifact(self, path: str) -> ValidationResult:
        """Scan a single artifact"""
        path_obj = Path(path)
        
        if not path_obj.exists():
            return ValidationResult(
                artifact_path=path,
                artifact_type=ArtifactType.UNKNOWN,
                is_valid=False,
                errors=[f"Artifact not found: {path}"]
            )
            
        # Detect artifact type
        artifact_type = self._detect_artifact_type(path_obj)
        
        # Calculate checksum
        checksum = await self._calculate_checksum(path_obj)
        
        # Extract manifest/metadata
        manifest = await self._extract_manifest(path_obj, artifact_type)
        
        # Validate artifact
        validation_errors = await self._validate_artifact(path_obj, artifact_type, manifest)
        
        return ValidationResult(
            artifact_path=path,
            artifact_type=artifact_type,
            is_valid=len(validation_errors) == 0,
            checksum=checksum,
            manifest=manifest,
            errors=validation_errors if validation_errors else None,
            metadata=await self._extract_metadata(path_obj, artifact_type)
        )
        
    def _detect_artifact_type(self, path: Path) -> ArtifactType:
        """Detect artifact type from file extension and content"""
        suffix = path.suffix.lower()
        
        if suffix in ['.jar', '.war', '.ear']:
            return ArtifactType.JAR
        elif suffix in ['.whl', '.egg']:
            return ArtifactType.WHEEL
        elif path.name == 'node_modules' or path.is_dir():
            return ArtifactType.NPM
        elif suffix in ['.tar.gz', '.tgz', '.tar']:
            return ArtifactType.TARBALL
        else:
            # Try to detect from content
            try:
                mime_type = self.file_magic.from_file(str(path))
                if 'zip' in mime_type:
                    return ArtifactType.JAR
                elif 'tar' in mime_type:
                    return ArtifactType.TARBALL
            except:
                pass
                
        return ArtifactType.UNKNOWN
        
    async def _calculate_checksum(self, path: Path, algorithm: str = 'sha256') -> str:
        """Calculate file checksum"""
        hash_func = hashlib.new(algorithm)
        
        if path.is_file():
            async with aio_open(path, 'rb') as f:
                while chunk := await f.read(8192):
                    hash_func.update(chunk)
        else:
            # For directories, hash all files
            for file_path in sorted(path.rglob('*')):
                if file_path.is_file():
                    async with aio_open(file_path, 'rb') as f:
                        while chunk := await f.read(8192):
                            hash_func.update(chunk)
                            
        return hash_func.hexdigest()
        
    async def _extract_manifest(self, path: Path, artifact_type: ArtifactType) -> Optional[Dict]:
        """Extract manifest/metadata from artifact"""
        manifest = {}
        
        try:
            if artifact_type == ArtifactType.JAR:
                # Extract MANIFEST.MF from JAR
                with zipfile.ZipFile(path, 'r') as jar:
                    if 'META-INF/MANIFEST.MF' in jar.namelist():
                        manifest_content = jar.read('META-INF/MANIFEST.MF').decode('utf-8')
                        manifest = self._parse_manifest(manifest_content)
                        
            elif artifact_type == ArtifactType.WHEEL:
                # Extract METADATA from wheel
                with zipfile.ZipFile(path, 'r') as wheel:
                    for name in wheel.namelist():
                        if name.endswith('/METADATA') or name.endswith('/metadata.json'):
                            metadata_content = wheel.read(name).decode('utf-8')
                            if name.endswith('.json'):
                                manifest = json.loads(metadata_content)
                            else:
                                manifest = self._parse_wheel_metadata(metadata_content)
                            break
                            
            elif artifact_type == ArtifactType.NPM:
                # Read package.json
                package_json_path = path / 'package.json'
                if package_json_path.exists():
                    async with aio_open(package_json_path, 'r') as f:
                        manifest = json.loads(await f.read())
                        
            elif artifact_type == ArtifactType.TARBALL:
                # Try to extract package info
                with tarfile.open(path, 'r:*') as tar:
                    for member in tar.getmembers():
                        if member.name.endswith('package.json') or member.name.endswith('setup.py'):
                            f = tar.extractfile(member)
                            if f:
                                content = f.read().decode('utf-8')
                                if member.name.endswith('.json'):
                                    manifest = json.loads(content)
                                break
                                
        except Exception as e:
            logger.error(f"Failed to extract manifest from {path}: {e}")
            
        return manifest if manifest else None
        
    def _parse_manifest(self, content: str) -> Dict:
        """Parse JAR MANIFEST.MF format"""
        manifest = {}
        for line in content.split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                manifest[key.strip()] = value.strip()
        return manifest
        
    def _parse_wheel_metadata(self, content: str) -> Dict:
        """Parse Python wheel METADATA format"""
        metadata = {}
        current_key = None
        
        for line in content.split('\n'):
            if ':' in line and not line.startswith(' '):
                key, value = line.split(':', 1)
                current_key = key.strip()
                metadata[current_key] = value.strip()
            elif current_key and line.startswith(' '):
                metadata[current_key] += '\n' + line.strip()
                
        return metadata
        
    async def _validate_artifact(self, path: Path, artifact_type: ArtifactType, 
                                manifest: Optional[Dict]) -> List[str]:
        """Validate artifact integrity and structure"""
        errors = []
        
        if artifact_type == ArtifactType.JAR:
            # Validate JAR structure
            try:
                with zipfile.ZipFile(path, 'r') as jar:
                    if jar.testzip():
                        errors.append("JAR file is corrupted")
                    if 'META-INF/MANIFEST.MF' not in jar.namelist():
                        errors.append("Missing MANIFEST.MF")
            except Exception as e:
                errors.append(f"Invalid JAR file: {e}")
                
        elif artifact_type == ArtifactType.WHEEL:
            # Validate wheel structure
            try:
                with zipfile.ZipFile(path, 'r') as wheel:
                    if wheel.testzip():
                        errors.append("Wheel file is corrupted")
                    # Check for required wheel files
                    has_metadata = any(name.endswith('/METADATA') for name in wheel.namelist())
                    if not has_metadata:
                        errors.append("Missing wheel METADATA")
            except Exception as e:
                errors.append(f"Invalid wheel file: {e}")
                
        elif artifact_type == ArtifactType.NPM:
            # Validate npm package structure
            if not (path / 'package.json').exists():
                errors.append("Missing package.json")
            else:
                # Validate package.json
                try:
                    async with aio_open(path / 'package.json', 'r') as f:
                        pkg = json.loads(await f.read())
                        if 'name' not in pkg:
                            errors.append("package.json missing 'name' field")
                        if 'version' not in pkg:
                            errors.append("package.json missing 'version' field")
                except Exception as e:
                    errors.append(f"Invalid package.json: {e}")
                    
        return errors
        
    async def _extract_metadata(self, path: Path, artifact_type: ArtifactType) -> Dict:
        """Extract additional metadata from artifact"""
        metadata = {
            'size': path.stat().st_size if path.is_file() else sum(
                f.stat().st_size for f in path.rglob('*') if f.is_file()
            ),
            'modified': datetime.fromtimestamp(path.stat().st_mtime).isoformat(),
            'type': artifact_type.value
        }
        
        if artifact_type == ArtifactType.JAR:
            # Count classes
            try:
                with zipfile.ZipFile(path, 'r') as jar:
                    class_files = [n for n in jar.namelist() if n.endswith('.class')]
                    metadata['class_count'] = len(class_files)
            except:
                pass
                
        elif artifact_type == ArtifactType.NPM and path.is_dir():
            # Count dependencies
            try:
                subdirs = [d for d in path.iterdir() if d.is_dir() and not d.name.startswith('.')]
                metadata['dependency_count'] = len(subdirs)
            except:
                pass
                
        return metadata

class BuildDiagnosticsEngine:
    """Diagnose build failures and suggest fixes"""
    
    def __init__(self, config: Dict):
        self.config = config
        self.error_patterns = config.get('build_diagnostics', {}).get('common_errors', [])
        
    async def diagnose_error(self, error_message: str, context: Dict = None) -> ErrorReport:
        """Diagnose error and suggest fix"""
        category = self._categorize_error(error_message)
        suggested_fix = self._suggest_fix(error_message, category, context)
        
        return ErrorReport(
            category=category,
            message=error_message,
            timestamp=datetime.now(),
            retry_count=0,
            resolved=False,
            suggested_fix=suggested_fix,
            context=context
        )
        
    def _categorize_error(self, error_message: str) -> ErrorCategory:
        """Categorize error based on patterns"""
        error_lower = error_message.lower()
        
        if any(pattern in error_lower for pattern in ['etimedout', 'econnrefused', 'enotfound']):
            return ErrorCategory.NETWORK
        elif '404' in error_message or 'not found' in error_lower:
            return ErrorCategory.PACKAGE_NOT_FOUND
        elif 'version' in error_lower and ('mismatch' in error_lower or 'conflict' in error_lower):
            return ErrorCategory.VERSION_MISMATCH
        elif 'checksum' in error_lower or 'integrity' in error_lower:
            return ErrorCategory.CHECKSUM_MISMATCH
        elif 'cannot resolve' in error_lower or 'module not found' in error_lower:
            return ErrorCategory.MISSING_DEPENDENCY
        elif 'vulnerability' in error_lower or 'cve-' in error_lower:
            return ErrorCategory.SECURITY_VULNERABILITY
        else:
            return ErrorCategory.BUILD_FAILURE
            
    def _suggest_fix(self, error_message: str, category: ErrorCategory, 
                    context: Dict = None) -> Optional[str]:
        """Suggest fix based on error pattern"""
        # Check configured patterns
        for pattern_config in self.error_patterns:
            if re.search(pattern_config['pattern'], error_message, re.IGNORECASE):
                return pattern_config.get('fix')
                
        # Default suggestions by category
        suggestions = {
            ErrorCategory.NETWORK: "Check network connection and proxy settings. Try: export HTTP_PROXY=your-proxy",
            ErrorCategory.PACKAGE_NOT_FOUND: "Verify package name and registry. Try: npm search <package-name>",
            ErrorCategory.VERSION_MISMATCH: "Check version constraints. Try: npm ls <package-name>",
            ErrorCategory.CHECKSUM_MISMATCH: "Clear cache and reinstall. Try: npm cache clean --force",
            ErrorCategory.MISSING_DEPENDENCY: "Install missing dependencies. Try: npm install",
            ErrorCategory.BUILD_FAILURE: "Check build logs for details. Try: npm run build --verbose"
        }
        
        return suggestions.get(category)
        
    async def analyze_build_log(self, log_content: str) -> List[ErrorReport]:
        """Analyze build log for errors"""
        errors = []
        
        # Split log into lines and look for error patterns
        for line in log_content.split('\n'):
            if any(indicator in line.lower() for indicator in ['error', 'failed', 'exception']):
                error_report = await self.diagnose_error(line)
                errors.append(error_report)
                
        return errors

class SocketMCP:
    """Main Socket MCP agent with enhanced error handling"""
    
    def __init__(self, config: Dict = None):
        self.config = config or self._load_config()
        self.retry_handler = RetryHandler(
            max_retries=self.config.get('error_handling', {}).get('max_retries', 3)
        )
        self.artifact_scanner = LocalArtifactScanner(self.config)
        self.diagnostics_engine = BuildDiagnosticsEngine(self.config)
        self.session = None
        self.errors: List[ErrorReport] = []
        self.api_key = os.environ.get('SOCKET_API_KEY')
        
    def _load_config(self) -> Dict:
        """Load configuration from YAML"""
        config_path = Path(__file__).parent.parent / 'socket-mcp.yaml'
        if config_path.exists():
            with open(config_path, 'r') as f:
                yaml_content = yaml.safe_load(f)
                return yaml_content.get('agent', {}).get('config', {})
        return {}
        
    async def __aenter__(self):
        """Async context manager entry"""
        timeout = aiohttp.ClientTimeout(
            total=self.config.get('error_handling', {}).get('timeout_per_request', 30)
        )
        self.session = aiohttp.ClientSession(timeout=timeout)
        return self
        
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        if self.session:
            await self.session.close()
            
    async def validate_packages(self, packages: List[str], 
                               artifact_paths: List[str] = None,
                               scan_local: bool = True) -> Dict:
        """Validate packages and local artifacts"""
        results = {
            'dependency_scores': [],
            'local_validation_report': {
                'scanned_artifacts': 0,
                'valid_artifacts': 0,
                'invalid_artifacts': []
            },
            'error_report': {
                'total_errors': 0,
                'network_errors': [],
                'validation_errors': [],
                'build_errors': [],
                'recovery_attempts': 0
            },
            'suggested_fixes': []
        }
        
        # Validate packages from registry
        for package in packages:
            try:
                score = await self._validate_package_registry(package)
                results['dependency_scores'].append(asdict(score))
            except Exception as e:
                error_report = await self.diagnostics_engine.diagnose_error(str(e))
                self.errors.append(error_report)
                results['error_report']['network_errors'].append(asdict(error_report))
                
                # Try local fallback
                if scan_local:
                    local_score = await self._validate_package_local(package)
                    if local_score:
                        results['dependency_scores'].append(asdict(local_score))
                        
        # Scan local artifacts
        if artifact_paths:
            for path in artifact_paths:
                validation_result = await self.artifact_scanner.scan_artifact(path)
                results['local_validation_report']['scanned_artifacts'] += 1
                
                if validation_result.is_valid:
                    results['local_validation_report']['valid_artifacts'] += 1
                else:
                    results['local_validation_report']['invalid_artifacts'].append(
                        asdict(validation_result)
                    )
                    
        # Generate fix suggestions
        for error in self.errors:
            if error.suggested_fix:
                results['suggested_fixes'].append({
                    'error_type': error.category.value,
                    'description': error.message,
                    'fix_command': error.suggested_fix,
                    'confidence': 0.8
                })
                
        # Update error counts
        results['error_report']['total_errors'] = len(self.errors)
        results['error_report']['recovery_attempts'] = sum(e.retry_count for e in self.errors)
        
        return results
        
    async def _validate_package_registry(self, package_spec: str) -> DependencyScore:
        """Validate package from registry with Socket.dev API"""
        # Parse package spec (name@version)
        parts = package_spec.split('@')
        package_name = parts[0]
        version = parts[1] if len(parts) > 1 else 'latest'
        
        # Call Socket.dev API with retry
        async def fetch_score():
            if not self.api_key:
                raise ValueError("SOCKET_API_KEY not set")
                
            headers = {'Authorization': f'Bearer {self.api_key}'}
            url = f"https://api.socket.dev/v0/npm/{package_name}/{version}/score"
            
            async with self.session.get(url, headers=headers) as response:
                if response.status == 404:
                    raise Exception(f"Package not found: {package_spec}")
                response.raise_for_status()
                return await response.json()
                
        try:
            data = await self.retry_handler.execute_with_retry(fetch_score)
            
            return DependencyScore(
                package=package_name,
                version=version,
                score=data.get('score', 0),
                risk_level=self._calculate_risk_level(data.get('score', 0)),
                vulnerabilities=data.get('vulnerabilities', []),
                license=data.get('license'),
                source='registry'
            )
        except Exception as e:
            logger.error(f"Failed to fetch package score for {package_spec}: {e}")
            raise
            
    async def _validate_package_local(self, package_spec: str) -> Optional[DependencyScore]:
        """Validate package from local artifacts"""
        package_name = package_spec.split('@')[0]
        
        # Search in common locations
        search_paths = self.config.get('local_scanning', {}).get('paths', {})
        
        for category, paths in search_paths.items():
            for path_pattern in paths:
                path = Path(path_pattern).expanduser()
                if path.exists():
                    # Look for package
                    if category == 'node_modules':
                        package_path = path / package_name
                        if package_path.exists():
                            validation = await self.artifact_scanner.scan_artifact(str(package_path))
                            if validation.is_valid and validation.manifest:
                                return DependencyScore(
                                    package=package_name,
                                    version=validation.manifest.get('version', 'unknown'),
                                    score=0.7,  # Default score for local
                                    risk_level='medium',
                                    vulnerabilities=[],
                                    license=validation.manifest.get('license'),
                                    source='local'
                                )
                                
        return None
        
    def _calculate_risk_level(self, score: float) -> str:
        """Calculate risk level from score"""
        if score >= 0.8:
            return 'low'
        elif score >= 0.5:
            return 'medium'
        else:
            return 'high'
            
    async def scan_directory(self, directory: str, recursive: bool = True) -> Dict:
        """Deep scan a directory for artifacts"""
        results = {
            'artifacts': [],
            'summary': {
                'total_files': 0,
                'valid_artifacts': 0,
                'security_issues': 0
            }
        }
        
        path = Path(directory)
        if not path.exists():
            raise ValueError(f"Directory not found: {directory}")
            
        # Find all potential artifacts
        patterns = ['*.jar', '*.whl', '*.tar.gz', 'package.json']
        
        for pattern in patterns:
            for file_path in path.rglob(pattern) if recursive else path.glob(pattern):
                results['summary']['total_files'] += 1
                
                validation = await self.artifact_scanner.scan_artifact(str(file_path))
                results['artifacts'].append(asdict(validation))
                
                if validation.is_valid:
                    results['summary']['valid_artifacts'] += 1
                    
        return results
        
    async def diagnose_build_failure(self, error_log_path: str, 
                                   project_path: str = '.') -> Dict:
        """Diagnose build failures from logs"""
        results = {
            'diagnostics': [],
            'root_causes': [],
            'suggested_actions': []
        }
        
        # Read error log
        with open(error_log_path, 'r') as f:
            log_content = f.read()
            
        # Analyze errors
        errors = await self.diagnostics_engine.analyze_build_log(log_content)
        results['diagnostics'] = [asdict(e) for e in errors]
        
        # Identify root causes
        error_categories = {}
        for error in errors:
            if error.category not in error_categories:
                error_categories[error.category] = 0
            error_categories[error.category] += 1
            
        # Most common error category is likely root cause
        if error_categories:
            root_cause = max(error_categories, key=error_categories.get)
            results['root_causes'].append({
                'category': root_cause.value,
                'frequency': error_categories[root_cause],
                'description': f"{root_cause.value} occurred {error_categories[root_cause]} times"
            })
            
        # Generate action plan
        seen_fixes = set()
        for error in errors:
            if error.suggested_fix and error.suggested_fix not in seen_fixes:
                results['suggested_actions'].append({
                    'priority': 'high' if error.category == root_cause else 'medium',
                    'action': error.suggested_fix,
                    'reason': error.message[:100]
                })
                seen_fixes.add(error.suggested_fix)
                
        return results
        
    async def compare_local_vs_registry(self, local_path: str, 
                                      package_spec: str) -> Dict:
        """Compare local artifact with registry version"""
        results = {
            'local': None,
            'registry': None,
            'differences': [],
            'recommendation': None
        }
        
        # Scan local artifact
        local_validation = await self.artifact_scanner.scan_artifact(local_path)
        results['local'] = asdict(local_validation)
        
        # Get registry info
        try:
            registry_score = await self._validate_package_registry(package_spec)
            results['registry'] = asdict(registry_score)
            
            # Compare versions
            if local_validation.manifest and 'version' in local_validation.manifest:
                local_version = local_validation.manifest['version']
                registry_version = registry_score.version
                
                if local_version != registry_version:
                    results['differences'].append({
                        'type': 'version',
                        'local': local_version,
                        'registry': registry_version
                    })
                    
            # Security comparison
            if registry_score.vulnerabilities:
                results['differences'].append({
                    'type': 'security',
                    'description': f"Registry version has {len(registry_score.vulnerabilities)} vulnerabilities"
                })
                
            # Generate recommendation
            if results['differences']:
                if any(d['type'] == 'security' for d in results['differences']):
                    results['recommendation'] = "Update to registry version to fix security issues"
                else:
                    results['recommendation'] = "Local version differs from registry, consider updating"
            else:
                results['recommendation'] = "Local artifact matches registry version"
                
        except Exception as e:
            results['registry'] = {'error': str(e)}
            results['recommendation'] = "Could not fetch registry info, using local artifact"
            
        return results

async def main():
    """CLI entry point"""
    parser = argparse.ArgumentParser(
        description='Socket MCP - Enhanced dependency validation'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # Validate command
    validate_parser = subparsers.add_parser('validate', help='Validate packages and artifacts')
    validate_parser.add_argument('--packages', '-p', nargs='+', help='Package specs to validate')
    validate_parser.add_argument('--artifact-paths', '-a', nargs='+', help='Local artifacts to validate')
    validate_parser.add_argument('--scan-local', action='store_true', default=True, help='Scan local artifacts')
    validate_parser.add_argument('--offline', action='store_true', help='Offline mode')
    
    # Scan command
    scan_parser = subparsers.add_parser('scan', help='Deep scan directory')
    scan_parser.add_argument('--path', '-p', required=True, help='Directory to scan')
    scan_parser.add_argument('--recursive', '-r', action='store_true', default=True, help='Recursive scan')
    
    # Diagnose command
    diagnose_parser = subparsers.add_parser('diagnose', help='Diagnose build failures')
    diagnose_parser.add_argument('--error-log', '-e', required=True, help='Error log file')
    diagnose_parser.add_argument('--project-path', '-p', default='.', help='Project path')
    
    # Compare command
    compare_parser = subparsers.add_parser('compare', help='Compare local vs registry')
    compare_parser.add_argument('--local-path', '-l', required=True, help='Local artifact path')
    compare_parser.add_argument('--package-spec', '-p', required=True, help='Package spec')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
        
    # Execute command
    async with SocketMCP() as socket_mcp:
        try:
            if args.command == 'validate':
                result = await socket_mcp.validate_packages(
                    packages=args.packages or [],
                    artifact_paths=args.artifact_paths,
                    scan_local=args.scan_local and not args.offline
                )
            elif args.command == 'scan':
                result = await socket_mcp.scan_directory(
                    args.path,
                    recursive=args.recursive
                )
            elif args.command == 'diagnose':
                result = await socket_mcp.diagnose_build_failure(
                    args.error_log,
                    args.project_path
                )
            elif args.command == 'compare':
                result = await socket_mcp.compare_local_vs_registry(
                    args.local_path,
                    args.package_spec
                )
            else:
                raise ValueError(f"Unknown command: {args.command}")
                
            # Output results
            print(json.dumps(result, indent=2, default=str))
            
        except Exception as e:
            logger.error(f"Command failed: {e}", exc_info=True)
            print(json.dumps({
                'status': 'error',
                'message': str(e)
            }, indent=2))
            sys.exit(1)

if __name__ == '__main__':
    asyncio.run(main())