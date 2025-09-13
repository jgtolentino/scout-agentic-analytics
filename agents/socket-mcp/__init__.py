"""
Socket MCP - Enhanced Build Guardrail & Dependency Validation Agent
Error-tolerant local+remote dependency validation with comprehensive security scanning
"""

from .main import (
    SocketMCP,
    LocalArtifactScanner,
    BuildDiagnosticsEngine,
    RetryHandler,
    ValidationResult,
    DependencyScore,
    ErrorReport,
    ErrorCategory,
    ArtifactType
)

from .error_handler import (
    SmartFixGenerator,
    ErrorReportGenerator,
    FixSuggestion,
    FixConfidence
)

from .security_scanner import (
    LocalArtifactSecurityScanner,
    SecurityAuditor,
    Vulnerability,
    SecurityScanResult
)

__version__ = "2.1.0"
__author__ = "TBWA Engineering"
__description__ = "Robust dependency validation and build guardrail with local artifact scanning"

__all__ = [
    # Main classes
    "SocketMCP",
    "LocalArtifactScanner",
    "BuildDiagnosticsEngine",
    "RetryHandler",
    
    # Data classes
    "ValidationResult",
    "DependencyScore",
    "ErrorReport",
    "ErrorCategory",
    "ArtifactType",
    
    # Error handling
    "SmartFixGenerator",
    "ErrorReportGenerator", 
    "FixSuggestion",
    "FixConfidence",
    
    # Security
    "LocalArtifactSecurityScanner",
    "SecurityAuditor",
    "Vulnerability",
    "SecurityScanResult"
]