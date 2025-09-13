#!/usr/bin/env python3
"""
Advanced error handling and fix suggestion generator
"""

import re
import json
from typing import Dict, List, Optional, Tuple
from enum import Enum
from dataclasses import dataclass, asdict
from datetime import datetime
import logging

logger = logging.getLogger('socket-mcp.error-handler')

class FixConfidence(Enum):
    HIGH = 0.9
    MEDIUM = 0.7
    LOW = 0.5
    EXPERIMENTAL = 0.3

@dataclass
class FixSuggestion:
    command: str
    description: str
    confidence: float
    prerequisites: List[str] = None
    alternatives: List[str] = None
    documentation_url: Optional[str] = None

class ErrorPatternMatcher:
    """Advanced pattern matching for error diagnosis"""
    
    def __init__(self):
        self.patterns = self._load_patterns()
        
    def _load_patterns(self) -> List[Dict]:
        """Load comprehensive error patterns"""
        return [
            # Network errors
            {
                'pattern': r'ETIMEDOUT|ESOCKETTIMEDOUT|timeout.*exceeded',
                'category': 'network_timeout',
                'fixes': [
                    FixSuggestion(
                        'npm config set fetch-retry-maxtimeout 120000',
                        'Increase npm timeout to 2 minutes',
                        FixConfidence.HIGH.value
                    ),
                    FixSuggestion(
                        'export NODE_OPTIONS="--max-http-header-size=16384"',
                        'Increase Node.js header size limit',
                        FixConfidence.MEDIUM.value
                    )
                ],
                'context_checks': ['npm', 'node']
            },
            {
                'pattern': r'ECONNREFUSED.*127\.0\.0\.1:(\d+)',
                'category': 'local_service_down',
                'fixes': [
                    FixSuggestion(
                        'Check if local service is running on port {port}',
                        'Verify local service status',
                        FixConfidence.HIGH.value,
                        prerequisites=['netstat -an | grep {port}']
                    )
                ],
                'extract_vars': {'port': 1}
            },
            {
                'pattern': r'getaddrinfo.*ENOTFOUND\s+(\S+)',
                'category': 'dns_resolution_failure',
                'fixes': [
                    FixSuggestion(
                        'nslookup {host}',
                        'Check DNS resolution for {host}',
                        FixConfidence.HIGH.value
                    ),
                    FixSuggestion(
                        'echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf',
                        'Use Google DNS as fallback',
                        FixConfidence.MEDIUM.value
                    )
                ],
                'extract_vars': {'host': 1}
            },
            
            # Package errors
            {
                'pattern': r'npm ERR!.*404.*[\'"]([^\'\"]+)[\'"].*is not in the npm registry',
                'category': 'package_not_found',
                'fixes': [
                    FixSuggestion(
                        'npm search {package}',
                        'Search for similar package names',
                        FixConfidence.HIGH.value
                    ),
                    FixSuggestion(
                        'npm config get registry',
                        'Check if using correct registry',
                        FixConfidence.MEDIUM.value
                    )
                ],
                'extract_vars': {'package': 1}
            },
            {
                'pattern': r'version solving failed.*package\s+([^\s]+)@([^\s]+)',
                'category': 'version_conflict',
                'fixes': [
                    FixSuggestion(
                        'npm ls {package}',
                        'Check dependency tree for {package}',
                        FixConfidence.HIGH.value
                    ),
                    FixSuggestion(
                        'npm install {package}@latest --force',
                        'Force install latest version',
                        FixConfidence.MEDIUM.value,
                        alternatives=['npm install {package}@{version} --legacy-peer-deps']
                    )
                ],
                'extract_vars': {'package': 1, 'version': 2}
            },
            
            # Build errors
            {
                'pattern': r'Module not found.*[\'"]([^\'\"]+)[\'"]',
                'category': 'missing_module',
                'fixes': [
                    FixSuggestion(
                        'npm install {module}',
                        'Install missing module',
                        FixConfidence.HIGH.value
                    ),
                    FixSuggestion(
                        'npm ci',
                        'Clean install from lockfile',
                        FixConfidence.MEDIUM.value,
                        prerequisites=['rm -rf node_modules']
                    )
                ],
                'extract_vars': {'module': 1}
            },
            {
                'pattern': r'SyntaxError.*Unexpected token.*at position (\d+)',
                'category': 'syntax_error',
                'fixes': [
                    FixSuggestion(
                        'npx eslint --fix .',
                        'Auto-fix syntax errors with ESLint',
                        FixConfidence.MEDIUM.value
                    ),
                    FixSuggestion(
                        'Check line near position {position} for syntax errors',
                        'Manual syntax check required',
                        FixConfidence.LOW.value
                    )
                ],
                'extract_vars': {'position': 1}
            },
            
            # Java/Maven errors
            {
                'pattern': r'Could not find artifact\s+([^\s]+)',
                'category': 'maven_artifact_not_found',
                'fixes': [
                    FixSuggestion(
                        'mvn dependency:get -Dartifact={artifact}',
                        'Download missing artifact',
                        FixConfidence.HIGH.value
                    ),
                    FixSuggestion(
                        'mvn clean install -U',
                        'Force update snapshots',
                        FixConfidence.MEDIUM.value
                    )
                ],
                'extract_vars': {'artifact': 1}
            },
            {
                'pattern': r'java\.lang\.ClassNotFoundException:\s+([^\s]+)',
                'category': 'class_not_found',
                'fixes': [
                    FixSuggestion(
                        'find . -name "*.jar" -exec jar tf {} \\; | grep {classname}',
                        'Search for class in JAR files',
                        FixConfidence.HIGH.value
                    ),
                    FixSuggestion(
                        'mvn dependency:tree | grep -B2 -A2 {classname}',
                        'Check dependency tree',
                        FixConfidence.MEDIUM.value
                    )
                ],
                'extract_vars': {'classname': 1}
            },
            
            # Python errors
            {
                'pattern': r'No module named [\'"]([^\'\"]+)[\'"]',
                'category': 'python_module_missing',
                'fixes': [
                    FixSuggestion(
                        'pip install {module}',
                        'Install missing Python module',
                        FixConfidence.HIGH.value
                    ),
                    FixSuggestion(
                        'pip install -r requirements.txt',
                        'Install from requirements file',
                        FixConfidence.MEDIUM.value
                    )
                ],
                'extract_vars': {'module': 1}
            },
            {
                'pattern': r'wheel.*error.*Microsoft Visual C\+\+.*required',
                'category': 'python_build_tools_missing',
                'fixes': [
                    FixSuggestion(
                        'Download Visual Studio Build Tools from https://visualstudio.microsoft.com/downloads/',
                        'Install Microsoft C++ Build Tools',
                        FixConfidence.HIGH.value,
                        documentation_url='https://wiki.python.org/moin/WindowsCompilers'
                    ),
                    FixSuggestion(
                        'pip install --only-binary :all: {package}',
                        'Use pre-compiled wheel only',
                        FixConfidence.MEDIUM.value
                    )
                ]
            },
            
            # Security/checksum errors
            {
                'pattern': r'sha(1|256|512) checksum.*mismatch|integrity.*verification.*failed',
                'category': 'checksum_mismatch',
                'fixes': [
                    FixSuggestion(
                        'npm cache clean --force',
                        'Clear npm cache completely',
                        FixConfidence.HIGH.value
                    ),
                    FixSuggestion(
                        'rm -rf node_modules package-lock.json && npm install',
                        'Full reinstall with fresh lockfile',
                        FixConfidence.MEDIUM.value
                    ),
                    FixSuggestion(
                        'npm audit fix',
                        'Fix known vulnerabilities',
                        FixConfidence.LOW.value
                    )
                ]
            }
        ]
        
    def match_error(self, error_message: str, context: Dict = None) -> List[Dict]:
        """Match error message against patterns"""
        matches = []
        
        for pattern_config in self.patterns:
            pattern = pattern_config['pattern']
            match = re.search(pattern, error_message, re.IGNORECASE | re.MULTILINE)
            
            if match:
                # Check context if specified
                if 'context_checks' in pattern_config and context:
                    if not any(check in str(context).lower() for check in pattern_config['context_checks']):
                        continue
                        
                # Extract variables if specified
                extracted_vars = {}
                if 'extract_vars' in pattern_config:
                    for var_name, group_num in pattern_config['extract_vars'].items():
                        if group_num <= len(match.groups()):
                            extracted_vars[var_name] = match.group(group_num)
                            
                # Prepare fixes with variable substitution
                fixes = []
                for fix_template in pattern_config.get('fixes', []):
                    fix = FixSuggestion(
                        command=fix_template.command.format(**extracted_vars),
                        description=fix_template.description.format(**extracted_vars),
                        confidence=fix_template.confidence,
                        prerequisites=[p.format(**extracted_vars) for p in (fix_template.prerequisites or [])],
                        alternatives=[a.format(**extracted_vars) for a in (fix_template.alternatives or [])],
                        documentation_url=fix_template.documentation_url
                    )
                    fixes.append(fix)
                    
                matches.append({
                    'category': pattern_config['category'],
                    'fixes': fixes,
                    'extracted_vars': extracted_vars,
                    'pattern': pattern
                })
                
        return matches

class SmartFixGenerator:
    """Generate intelligent fix suggestions based on error context"""
    
    def __init__(self):
        self.pattern_matcher = ErrorPatternMatcher()
        self.fix_history = []  # Track what fixes have been tried
        
    async def generate_fixes(self, error_message: str, context: Dict = None, 
                           previous_attempts: List[str] = None) -> List[FixSuggestion]:
        """Generate smart fix suggestions"""
        fixes = []
        
        # Get pattern-based fixes
        matches = self.pattern_matcher.match_error(error_message, context)
        
        for match in matches:
            for fix in match['fixes']:
                # Skip fixes that have been tried
                if previous_attempts and fix.command in previous_attempts:
                    fix.confidence *= 0.5  # Reduce confidence for repeated fixes
                    
                fixes.append(fix)
                
        # If no pattern matches, try generic fixes
        if not fixes:
            fixes.extend(self._get_generic_fixes(error_message, context))
            
        # Sort by confidence
        fixes.sort(key=lambda f: f.confidence, reverse=True)
        
        # Add context-aware enhancements
        fixes = self._enhance_fixes_with_context(fixes, context)
        
        return fixes[:5]  # Return top 5 fixes
        
    def _get_generic_fixes(self, error_message: str, context: Dict = None) -> List[FixSuggestion]:
        """Get generic fixes for unmatched errors"""
        fixes = []
        
        # Package manager detection
        if context and 'package_manager' in context:
            pm = context['package_manager']
            if pm == 'npm':
                fixes.extend([
                    FixSuggestion(
                        'npm ci',
                        'Clean install dependencies',
                        FixConfidence.MEDIUM.value
                    ),
                    FixSuggestion(
                        'npm update',
                        'Update all dependencies',
                        FixConfidence.LOW.value
                    )
                ])
            elif pm == 'pip':
                fixes.extend([
                    FixSuggestion(
                        'pip install --upgrade pip',
                        'Upgrade pip itself',
                        FixConfidence.MEDIUM.value
                    ),
                    FixSuggestion(
                        'pip install --force-reinstall -r requirements.txt',
                        'Force reinstall all dependencies',
                        FixConfidence.LOW.value
                    )
                ])
                
        # Generic debugging
        fixes.append(
            FixSuggestion(
                'echo "Error details:" && cat build.log | grep -A5 -B5 -i error',
                'Show error context from build log',
                FixConfidence.LOW.value
            )
        )
        
        return fixes
        
    def _enhance_fixes_with_context(self, fixes: List[FixSuggestion], 
                                   context: Dict = None) -> List[FixSuggestion]:
        """Enhance fixes based on context"""
        if not context:
            return fixes
            
        enhanced_fixes = []
        
        for fix in fixes:
            # Add OS-specific variants
            if 'os' in context:
                if context['os'] == 'windows' and 'sudo' in fix.command:
                    # Windows variant without sudo
                    win_fix = FixSuggestion(
                        command=fix.command.replace('sudo ', ''),
                        description=f"{fix.description} (Windows)",
                        confidence=fix.confidence * 0.9,
                        prerequisites=fix.prerequisites,
                        alternatives=fix.alternatives
                    )
                    enhanced_fixes.append(win_fix)
                    
            # Add containerized variants
            if context.get('containerized', False):
                container_fix = FixSuggestion(
                    command=f"docker exec -it ${{CONTAINER_ID}} {fix.command}",
                    description=f"{fix.description} (in container)",
                    confidence=fix.confidence * 0.8,
                    prerequisites=['docker ps | grep your-app']
                )
                enhanced_fixes.append(container_fix)
                
            enhanced_fixes.append(fix)
            
        return enhanced_fixes

class ErrorReportGenerator:
    """Generate comprehensive error reports with actionable insights"""
    
    def __init__(self):
        self.fix_generator = SmartFixGenerator()
        
    async def generate_report(self, errors: List[Dict], context: Dict = None) -> Dict:
        """Generate comprehensive error report"""
        report = {
            'summary': {
                'total_errors': len(errors),
                'categories': {},
                'critical_errors': 0,
                'resolved_errors': 0
            },
            'timeline': [],
            'root_cause_analysis': {},
            'action_plan': [],
            'prevention_suggestions': []
        }
        
        # Categorize errors
        for error in errors:
            category = error.get('category', 'unknown')
            if category not in report['summary']['categories']:
                report['summary']['categories'][category] = 0
            report['summary']['categories'][category] += 1
            
            # Track timeline
            report['timeline'].append({
                'timestamp': error.get('timestamp', datetime.now()).isoformat(),
                'category': category,
                'message': error.get('message', '')[:200],
                'resolved': error.get('resolved', False)
            })
            
            if error.get('resolved', False):
                report['summary']['resolved_errors'] += 1
                
        # Root cause analysis
        most_common_category = max(report['summary']['categories'].items(), 
                                 key=lambda x: x[1])[0] if report['summary']['categories'] else 'unknown'
        
        report['root_cause_analysis'] = {
            'likely_root_cause': most_common_category,
            'confidence': min(report['summary']['categories'].get(most_common_category, 0) / len(errors), 1.0),
            'related_errors': [e for e in errors if e.get('category') == most_common_category]
        }
        
        # Generate action plan
        seen_categories = set()
        for error in errors:
            if error.get('category') in seen_categories:
                continue
                
            fixes = await self.fix_generator.generate_fixes(
                error.get('message', ''),
                context
            )
            
            if fixes:
                report['action_plan'].append({
                    'step': len(report['action_plan']) + 1,
                    'category': error.get('category'),
                    'primary_fix': asdict(fixes[0]),
                    'alternatives': [asdict(f) for f in fixes[1:3]]
                })
                seen_categories.add(error.get('category'))
                
        # Prevention suggestions
        report['prevention_suggestions'] = self._generate_prevention_suggestions(
            report['summary']['categories']
        )
        
        return report
        
    def _generate_prevention_suggestions(self, error_categories: Dict[str, int]) -> List[Dict]:
        """Generate prevention suggestions based on error patterns"""
        suggestions = []
        
        if error_categories.get('network_timeout', 0) > 2:
            suggestions.append({
                'issue': 'Frequent network timeouts',
                'suggestion': 'Configure local package cache or mirror',
                'commands': [
                    'npm config set cache-min 9999999',
                    'npm config set prefer-offline true'
                ]
            })
            
        if error_categories.get('checksum_mismatch', 0) > 0:
            suggestions.append({
                'issue': 'Checksum verification failures',
                'suggestion': 'Use lockfiles and verify integrity',
                'commands': [
                    'npm ci instead of npm install',
                    'git add package-lock.json'
                ]
            })
            
        if error_categories.get('version_conflict', 0) > 1:
            suggestions.append({
                'issue': 'Version conflicts',
                'suggestion': 'Use exact versions and peer dependency management',
                'commands': [
                    'npm config set save-exact true',
                    'npx npm-check-updates'
                ]
            })
            
        return suggestions

# Export main classes
__all__ = ['SmartFixGenerator', 'ErrorReportGenerator', 'FixSuggestion']